// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../upkeeps/CronUpkeep.sol";
import {CronUtility_Internal, Spec} from "../libraries/CronUtility_Internal.sol";

/**
 * @title The CronUpkeepTestHelper contract
 * @notice This contract exposes core functionality of the CronUpkeep contract.
 * It is only intended for use in tests.
 */
contract CronUpkeepTestHelper is CronUpkeep {
  using CronUtility_Internal for Spec;
  using CronUtility_Internal for string;

  constructor(address owner, address delegate) CronUpkeep(owner, delegate) {}

  /**
   * @notice createCronJobFromString is a helper function for creating cron jobs
   * directly from strings. This is gas-intensive and shouldn't be done outside
   * of testing environments.
   */
  function createCronJobFromString(
    address target,
    bytes memory handler,
    string memory cronString
  ) external {
    Spec memory spec = cronString.toSpec();
    createCronJobFromSpec(target, handler, spec);
  }

  /**
   * @notice txCheckUpkeep is a helper function for sending real txs to the
   * checkUpkeep function. This allows us to do gas analysis on it.
   */
  function txCheckUpkeep(bytes calldata checkData) external {
    address(this).call(
      abi.encodeWithSelector(bytes4(keccak256("checkUpkeep(bytes)")), checkData)
    );
  }
}
