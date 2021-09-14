// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import {CronUtility, Spec} from "../libraries/CronUtility.sol";

/**
 * @title The CronUtilityTestHelper contract
 * @notice This contract exposes core functionality of the CronUtility library.
 * It is only intended for use in tests.
 */
contract CronUtilityTestHelper {
  using CronUtility for Spec;
  using CronUtility for string;

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
    Spec memory spec = abi.decode(encodedSpec, (Spec));
    return spec.toCronString();
  }

  /**
   * @notice encodedSpecToString is a helper function for turning a string
   * into a spec struct.
   */
  function cronStringToEncodedSpec(string memory cronString)
    public
    pure
    returns (Spec memory)
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
