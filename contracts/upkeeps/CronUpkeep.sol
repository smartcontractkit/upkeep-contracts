// SPDX-License-Identifier: MIT

/**
  The Cron contract is a chainlink keepers-powered cron job runner for smart contracts.
  The contract enables developers to trigger actions on various targets using cron
  strings to specify the cadence. For example, a user may have 3 tasks that require
  regular service in their dapp ecosystem:
    1) 0xAB..CD, update(1), "0 0 * * *"     --> runs update(1) on 0xAB..CD daily at midnight
    2) 0xAB..CD, update(2), "30 12 * * 0-4" --> runs update(2) on 0xAB..CD weekdays at 12:30
    3) 0x12..34, trigger(), "0 * * * *"     --> runs trigger() on 0x12..34 hourly

  To use this contract, a user first deploys this contract and registers it on the chainlink
  keeper registry. Then the user adds cron jobs by following these steps:
    1) Convert a cron string to an encoded cron spec by calling encodeCronString()
    2) Take the encoding, target, and handler, and create a job by sending a tx to createCronJob()
    3) Cron job is running :)
*/

pragma solidity 0.8.6;

import "../interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/dev/ConfirmedOwner.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {CronUtility, Spec} from "../libraries/CronUtility.sol";
import {getRevertMsg} from "../utils/utils.sol";

/**
 * @title The CronUpkeep contract
 * @notice A keeper-compatible contract that runs various tasks on cron schedules.
 * Users must use the encodeCronString() function to encode their cron jobs before
 * setting them. This keeps all the string manipulation off chain and reduces gas costs.
 */
contract CronUpkeep is KeeperCompatibleInterface, ConfirmedOwner, Pausable {
  using CronUtility for Spec;
  using CronUtility for string;

  event CronJobExecuted(uint256 indexed id, uint256 timestamp);
  event CronJobCreated(uint256 indexed id, address target, bytes handler);
  event CronJobDeleted(uint256 indexed id);

  error CallFailed(uint256 id, string reason);
  error CronJobIDNotFound(uint256 id);
  error InvalidHandler();
  error TickInFuture();
  error TickTooOld();
  error TickDoesntMatchSpec();

  uint256 private s_nextCronJobID = 1;
  uint256[] private s_activeCronJobIDs;

  mapping(uint256 => uint256) private s_lastRuns;
  mapping(uint256 => Spec) private s_specs;
  mapping(uint256 => address) private s_targets;
  mapping(uint256 => bytes) private s_handlers;
  mapping(uint256 => bytes32) private s_handlerSignatures;

  constructor() ConfirmedOwner(msg.sender) {}

  /**
   * @notice Executes the cron job with id encoded in performData
   * @param performData abi encoding of cron job ID and the cron job's next run-at datetime
   */
  function performUpkeep(bytes calldata performData)
    external
    override
    whenNotPaused
  {
    (uint256 id, uint256 tickTime, address target, bytes memory handler) = abi
      .decode(performData, (uint256, uint256, address, bytes));
    validate(id, tickTime, target, handler);
    s_lastRuns[id] = block.timestamp;
    (bool success, bytes memory payload) = target.call(handler);
    if (!success) {
      revert CallFailed(id, getRevertMsg(payload));
    }
    emit CronJobExecuted(id, block.timestamp);
  }

  /**
   * @notice Creates a cron job from the given encoded spec
   * @param target the destination contract of a cron job
   * @param handler the function signature on the target contract to call
   * @param encodedCronSpec abi encoding of a cron spec
   */
  function createCronJobFromEncodedSpec(
    address target,
    bytes memory handler,
    bytes memory encodedCronSpec
  ) external {
    Spec memory spec = abi.decode(encodedCronSpec, (Spec));
    createCronJobFromSpec(target, handler, spec);
  }

  /**
   * @notice Deletes the cron job matching the provided id. Reverts if
   * the id is not found.
   * @param id the id of the cron job to delete
   */
  function deleteCronJob(uint256 id) external onlyOwner {
    if (s_targets[id] == address(0)) {
      revert CronJobIDNotFound(id);
    }
    uint256 existingID;
    uint256 oldLength = s_activeCronJobIDs.length;
    uint256 newLength = oldLength - 1;
    uint256 idx;
    for (idx = 0; idx < newLength; idx++) {
      existingID = s_activeCronJobIDs[idx];
      if (existingID == id) {
        s_activeCronJobIDs[idx] = s_activeCronJobIDs[newLength];
        break;
      }
    }
    delete s_lastRuns[id];
    delete s_specs[id];
    delete s_targets[id];
    delete s_handlers[id];
    delete s_handlerSignatures[id];
    s_activeCronJobIDs.pop();
    emit CronJobDeleted(id);
  }

  /**
   * @notice Pauses the contract, which prevents executing performUpkeep
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Unpauses the contract
   */
  function unpause() external onlyOwner {
    _unpause();
  }

  /**
   * @notice Get the id of an eligible cron job
   * @return upkeepNeeded signals if upkeep is needed, performData is an abi encoding
   * of the id and "next tick" of the elligible cron job
   */
  function checkUpkeep(bytes calldata)
    external
    view
    override
    whenNotPaused
    returns (bool, bytes memory)
  {
    // DEV: start at a random spot in the list so that checks are
    // spread evenly among cron jobs
    uint256 numCrons = s_activeCronJobIDs.length;
    uint256 startIdx = block.number % numCrons;
    bool result;
    bytes memory payload;
    (result, payload) = checkInRange(startIdx, numCrons);
    if (result) {
      return (result, payload);
    }
    (result, payload) = checkInRange(0, startIdx);
    if (result) {
      return (result, payload);
    }
    return (false, bytes(""));
  }

  function checkInRange(uint256 start, uint256 end)
    private
    view
    returns (bool, bytes memory)
  {
    uint256 id;
    uint256 lastTick;
    for (uint256 idx = start; idx < end; idx++) {
      id = s_activeCronJobIDs[idx];
      lastTick = s_specs[id].lastTick();
      if (lastTick > s_lastRuns[id]) {
        return (true, abi.encode(id, lastTick, s_targets[id], s_handlers[id]));
      }
    }
  }

  /**
   * @notice gets a list of active cron job IDs
   * @return list of active cron job IDs
   */
  function getActiveCronJobIDs() external view returns (uint256[] memory) {
    return s_activeCronJobIDs;
  }

  /**
   * @notice gets a cron job
   * @param id the cron job ID
   * @return target - the address a cron job forwards the eth tx to
             handler - the encoded function sig to execute when forwarding a tx
             cronString - the string representing the cron job
             nextTick - the timestamp of the next time the cron job will run
   */
  function getCronJob(uint256 id)
    external
    view
    returns (
      address target,
      bytes memory handler,
      string memory cronString,
      uint256 nextTick
    )
  {
    Spec memory spec = s_specs[id];
    return (
      s_targets[id],
      s_handlers[id],
      spec.toCronString(),
      spec.nextTick()
    );
  }

  /**
   * @notice Converts a cron string to a Spec, validates the spec, and encodes the spec.
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to convert and encode
   * @return the abi encoding of the Spec struct representing the cron string
   */
  function cronStringToEncodedSpec(string memory cronString)
    external
    pure
    returns (bytes memory)
  {
    return cronString.toEncodedSpec();
  }

  /**
   * @notice Adds a cron spec to storage and the ID to the list of jobs
   * @param target the destination contract of a cron job
   * @param handler the function signature on the target contract to call
   * @param spec the cron spec to create
   */

  function createCronJobFromSpec(
    address target,
    bytes memory handler,
    Spec memory spec
  ) internal onlyOwner {
    uint256 newID = s_nextCronJobID;
    s_activeCronJobIDs.push(newID);
    s_targets[newID] = target;
    s_handlers[newID] = handler;
    s_specs[newID] = spec;
    s_lastRuns[newID] = block.timestamp;
    s_handlerSignatures[newID] = handlerSig(target, handler);
    s_nextCronJobID++;
    emit CronJobCreated(newID, target, handler);
  }

  function validate(
    uint256 id,
    uint256 tickTime,
    address target,
    bytes memory handler
  ) private {
    if (block.timestamp < tickTime) {
      revert TickInFuture();
    }
    if (tickTime <= s_lastRuns[id]) {
      revert TickTooOld();
    }
    if (!s_specs[id].matches(tickTime)) {
      revert TickDoesntMatchSpec();
    }
    if (handlerSig(target, handler) != s_handlerSignatures[id]) {
      revert InvalidHandler();
    }
  }

  function handlerSig(address target, bytes memory handler)
    private
    pure
    returns (bytes32)
  {
    return keccak256(abi.encodePacked(target, handler));
  }
}
