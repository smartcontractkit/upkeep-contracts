// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../interfaces/KeeperCompatibleInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/dev/ConfirmedOwner.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title The EthBalanceMonitor contract
 * @notice A keeper-compatible contract that monitors and funds eth addresses
 */
contract EthBalanceMonitor is
  ConfirmedOwner,
  Pausable,
  KeeperCompatibleInterface
{
  // observed limit of 45K + 10k buffer
  uint256 private constant MIN_GAS_FOR_TRANSFER = 55_000;

  event FundsAdded(uint256 amountAdded, uint256 newBalance);
  event FundsWithdrawn(uint256 amountWithdrawn, address payee);
  event TopUpSucceeded(address indexed recipient);
  event TopUpFailed(address indexed recipient);
  event KeeperRegistryAddressUpdated(address oldAddress, address newAddress);
  event MinWaitPeriodUpdated(
    uint256 oldMinWaitPeriod,
    uint256 newMinWaitPeriod
  );

  error UnequalListLengths();
  error PermissionDenied();
  error DuplicateAddress(address duplicate);

  struct Target {
    bool isActive;
    uint96 minBalanceWei;
    uint96 topUpAmountWei;
    uint56 lastTopUpBlock;
  }

  address private s_keeperRegistryAddress;
  uint256 private s_minWaitPeriod;
  address[] private s_watchList;
  mapping(address => Target) internal s_targets;

  /**
   * @param keeperRegistryAddress The address of the keeper registry contract
   * @param minWaitPeriod The minimum wait period for addresses between funding
   */
  constructor(address keeperRegistryAddress, uint256 minWaitPeriod)
    ConfirmedOwner(msg.sender)
  {
    setKeeperRegistryAddress(keeperRegistryAddress);
    setMinWaitPeriod(minWaitPeriod);
  }

  /**
   * @notice Sets the list of addresses to watch and their funding parameters
   * @param addresses the list of addresses to watch
   * @param minBalancesWei the minimum balances for each address
   * @param topUpAmountsWei the amount to top up each address
   */
  function setWatchList(
    address[] calldata addresses,
    uint96[] calldata minBalancesWei,
    uint96[] calldata topUpAmountsWei
  ) external onlyOwner() {
    if (
      addresses.length != minBalancesWei.length ||
      addresses.length != topUpAmountsWei.length
    ) {
      revert UnequalListLengths();
    }
    address[] memory oldWatchList = s_watchList;
    for (uint256 idx = 0; idx < oldWatchList.length; idx++) {
      s_targets[oldWatchList[idx]].isActive = false;
    }
    for (uint256 idx = 0; idx < addresses.length; idx++) {
      if (s_targets[addresses[idx]].isActive) {
        revert DuplicateAddress(addresses[idx]);
      }
      s_targets[addresses[idx]] = Target({
        isActive: true,
        minBalanceWei: minBalancesWei[idx],
        topUpAmountWei: topUpAmountsWei[idx],
        lastTopUpBlock: 0
      });
    }
    s_watchList = addresses;
  }

  /**
   * @notice Sends funds to the addresses provided
   * @param needsFunding the list of addresses to fund
   */
  function topUp(address[] memory needsFunding) public onlyKeeperOrOwner() {
    uint256 minWaitPeriod = s_minWaitPeriod;
    Target memory target;
    for (uint256 idx = 0; idx < needsFunding.length; idx++) {
      target = s_targets[needsFunding[idx]];
      if (
        target.isActive &&
        target.lastTopUpBlock + minWaitPeriod <= block.number &&
        needsFunding[idx].balance < target.minBalanceWei
      ) {
        bool success = payable(needsFunding[idx]).send(target.topUpAmountWei);
        if (success) {
          s_targets[needsFunding[idx]].lastTopUpBlock = uint56(block.number);
          emit TopUpSucceeded(needsFunding[idx]);
        } else {
          emit TopUpFailed(needsFunding[idx]);
        }
      }
      if (gasleft() < MIN_GAS_FOR_TRANSFER) {
        return;
      }
    }
  }

  /**
   * @notice Gets a list of addresses that are under funded
   * @return list of addresses that are underfunded
   */
  function getUnderfundedAddresses() public view returns (address[] memory) {
    address[] memory watchList = s_watchList;
    address[] memory needsFunding = new address[](watchList.length);
    uint256 count = 0;
    uint256 minWaitPeriod = s_minWaitPeriod;
    uint256 balance = address(this).balance;
    Target memory target;
    for (uint256 idx = 0; idx < watchList.length; idx++) {
      target = s_targets[watchList[idx]];
      if (
        target.lastTopUpBlock + minWaitPeriod <= block.number &&
        balance >= target.topUpAmountWei &&
        watchList[idx].balance < target.minBalanceWei
      ) {
        needsFunding[count] = watchList[idx];
        count++;
        balance -= target.topUpAmountWei;
      }
    }
    if (count != watchList.length) {
      assembly {
        mstore(needsFunding, count)
      }
    }
    return needsFunding;
  }

  /**
   * @notice Get list of addresses that are underfunded and return keeper-compatible payload
   * @return upkeepNeeded signals if upkeep is needed, performData is an abi encoded list of addresses that need funds
   */
  function checkUpkeep(bytes calldata)
    external
    view
    override
    returns (bool upkeepNeeded, bytes memory performData)
  {
    address[] memory needsFunding = getUnderfundedAddresses();
    upkeepNeeded = needsFunding.length > 0;
    performData = abi.encode(needsFunding);
    return (upkeepNeeded, performData);
  }

  /**
   * @notice Called by keeper to send funds to underfunded addresses
   * @param performData The abi encoded list of addresses to fund
   */
  function performUpkeep(bytes calldata performData)
    external
    override
    onlyKeeper()
    whenNotPaused()
  {
    address[] memory needsFunding = abi.decode(performData, (address[]));
    topUp(needsFunding);
  }

  /**
   * @notice Withdraws the contract balance
   * @param amount The amount of eth (in wei) to withdraw
   * @param payee The address to pay
   */
  function withdraw(uint256 amount, address payable payee)
    external
    onlyOwner()
  {
    require(payee != address(0));
    emit FundsWithdrawn(amount, payee);
    payee.transfer(amount);
  }

  /**
   * @notice Receive funds
   */
  receive() external payable {
    emit FundsAdded(msg.value, address(this).balance);
  }

  /**
   * @notice Sets the keeper registry address
   */
  function setKeeperRegistryAddress(address keeperRegistryAddress)
    public
    onlyOwner()
  {
    require(keeperRegistryAddress != address(0));
    emit KeeperRegistryAddressUpdated(
      s_keeperRegistryAddress,
      keeperRegistryAddress
    );
    s_keeperRegistryAddress = keeperRegistryAddress;
  }

  /**
   * @notice Sets the minimum wait period for addresses between funding
   */
  function setMinWaitPeriod(uint256 minWaitPeriod) public onlyOwner() {
    emit MinWaitPeriodUpdated(s_minWaitPeriod, minWaitPeriod);
    s_minWaitPeriod = minWaitPeriod;
  }

  /**
   * @notice Gets the keeper registry address
   */
  function getKeeperRegistryAddress()
    external
    view
    returns (address keeperRegistryAddress)
  {
    return s_keeperRegistryAddress;
  }

  /**
   * @notice Gets the minimum wait period
   */
  function getMinWaitPeriod() external view returns (uint256 minWaitPeriod) {
    return s_minWaitPeriod;
  }

  /**
   * @notice Gets the list of addresses being watched
   */
  function getWatchList() external view returns (address[] memory) {
    return s_watchList;
  }

  /**
   * @notice Gets configuration information for an address on the watchlist
   */
  function getAccountInfo(address targetAddress)
    external
    view
    returns (
      bool isActive,
      uint256 minBalanceWei,
      uint256 topUpAmountWei,
      uint256 lastTopUpBlock
    )
  {
    Target memory target = s_targets[targetAddress];
    return (
      target.isActive,
      target.minBalanceWei,
      target.topUpAmountWei,
      target.lastTopUpBlock
    );
  }

  /**
   * @notice Pauses the contract, which prevents executing performUpkeep
   */
  function pause() external onlyOwner() {
    _pause();
  }

  /**
   * @notice Unpauses the contract
   */
  function unpause() external onlyOwner() {
    _unpause();
  }

  modifier onlyKeeper() {
    if (msg.sender != s_keeperRegistryAddress) {
      revert PermissionDenied();
    }
    _;
  }

  modifier onlyKeeperOrOwner() {
    if (msg.sender != s_keeperRegistryAddress && msg.sender != owner()) {
      revert PermissionDenied();
    }
    _;
  }
}
