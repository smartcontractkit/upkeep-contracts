// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import {CronUtility_Internal, Spec as Spec_In} from "../libraries/CronUtility_Internal.sol";
import {CronUtility_External, Spec as Spec_Ex} from "../libraries/CronUtility_External.sol";

/**
 * @title The CronUtilityInternalTestHelper contract
 * @notice This contract exposes core functionality of the CronUtility_Internal library.
 * It is only intended for use in tests.
 */
contract CronUtilityInternalTestHelper {
  using CronUtility_Internal for Spec_In;
  using CronUtility_Internal for string;

  /**
   * @notice Converts a cron string to a Spec, validates the spec, and encodes the spec.
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to convert and encode
   * @return the abi encoding of the Spec struct representing the cron string
   */
  function encodeCronString(string memory cronString)
    external
    pure
    returns (bytes memory)
  {
    return cronString.toEncodedSpec();
  }

  /**
   * @notice encodedSpecToString is a helper function for turning an
   * encoded spec back into a string. There is limited or no use for this outside
   * of tests.
   */
  function encodedSpecToString(bytes memory encodedSpec)
    public
    pure
    returns (string memory)
  {
    Spec_In memory spec = abi.decode(encodedSpec, (Spec_In));
    return spec.toCronString();
  }

  /**
   * @notice encodedSpecToString is a helper function for turning a string
   * into a spec struct.
   */
  function cronStringToEncodedSpec(string memory cronString)
    public
    pure
    returns (Spec_In memory)
  {
    return cronString.toSpec();
  }

  /**
   * @notice calculateNextTick calculates the next time a cron job should "tick".
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to consider
   * @return the timestamp in UTC of the next "tick"
   */
  function calculateNextTick(string memory cronString)
    external
    view
    returns (uint256)
  {
    return cronString.toSpec().nextTick();
  }

  /**
   * @notice calculateLastTick calculates the last time a cron job "ticked".
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to consider
   * @return the timestamp in UTC of the last "tick"
   */
  function calculateLastTick(string memory cronString)
    external
    view
    returns (uint256)
  {
    return cronString.toSpec().lastTick();
  }
}

/**
 * @title The CronUtilityExternalTestHelper contract
 * @notice This contract exposes core functionality of the CronUtility_External library.
 * It is only intended for use in tests.
 */
contract CronUtilityExternalTestHelper {
  using CronUtility_External for Spec_Ex;
  using CronUtility_External for string;

  /**
   * @notice Converts a cron string to a Spec, validates the spec, and encodes the spec.
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to convert and encode
   * @return the abi encoding of the Spec struct representing the cron string
   */
  function encodeCronString(string memory cronString)
    external
    pure
    returns (bytes memory)
  {
    return cronString.toEncodedSpec();
  }

  /**
   * @notice encodedSpecToString is a helper function for turning an
   * encoded spec back into a string. There is limited or no use for this outside
   * of tests.
   */
  function encodedSpecToString(bytes memory encodedSpec)
    public
    pure
    returns (string memory)
  {
    Spec_Ex memory spec = abi.decode(encodedSpec, (Spec_Ex));
    return spec.toCronString();
  }

  /**
   * @notice encodedSpecToString is a helper function for turning a string
   * into a spec struct.
   */
  function cronStringToEncodedSpec(string memory cronString)
    public
    pure
    returns (Spec_Ex memory)
  {
    return cronString.toSpec();
  }

  /**
   * @notice calculateNextTick calculates the next time a cron job should "tick".
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to consider
   * @return the timestamp in UTC of the next "tick"
   */
  function calculateNextTick(string memory cronString)
    external
    view
    returns (uint256)
  {
    return cronString.toSpec().nextTick();
  }

  /**
   * @notice calculateLastTick calculates the last time a cron job "ticked".
   * This should only be called off-chain, as it is gas expensive!
   * @param cronString the cron string to consider
   * @return the timestamp in UTC of the last "tick"
   */
  function calculateLastTick(string memory cronString)
    external
    view
    returns (uint256)
  {
    return cronString.toSpec().lastTick();
  }
}
