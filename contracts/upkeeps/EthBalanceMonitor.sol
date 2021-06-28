// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../interfaces/KeeperCompatibleInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title The EthBalanceMonitor contract
 * @notice A keeper-compatible contract that monitors and funds eth addresses
 */
contract EthBalanceMonitor is Ownable, Pausable, KeeperCompatibleInterface {

  uint256 constant private MIN_GAS_FOR_TRANSFER = 70000;

  event FundsAdded (
    uint256 newBalance
  );

  event TopUpSucceeded (
    address indexed recipient
  );

  event TopUpFailed (
    address indexed recipient
  );

  struct Config {
    bool isActive;
    uint256 minBalanceWei;
    uint256 topUpAmountWei;
    uint256 lastTopUp;
  }

  address private s_keeperRegistryAddress;
  uint256 private s_minWaitPeriod;
  address[] private s_watchList;
  mapping (address=>Config) internal accountConfigs;

  /**
   * @param _keeperRegistryAddress The address of the keeper registry contract
   * @param _minWaitPeriod The minimum wait period for addresses between funding
   */
  constructor(address _keeperRegistryAddress, uint256 _minWaitPeriod) {
    s_keeperRegistryAddress = _keeperRegistryAddress;
    s_minWaitPeriod = _minWaitPeriod;
  }

  /**
   * @notice Receive funds
   */
  receive() external payable {
    emit FundsAdded(address(this).balance);
  }

  /**
   * @notice Withdraws the contract balance
   * @param _amount The amount of eth (in wei) to withdraw
   * @param _payee The address to pay
   */
  function withdraw(uint256 _amount, address payable _payee) external onlyOwner {
    _payee.transfer(_amount);
  }

  /**
   * @notice Gets the keeper registry address
   */
  function getKeeperRegistryAddress() public view returns(address keeperRegistryAddress) {
    return s_keeperRegistryAddress;
  }

  /**
   * @notice Sets the keeper registry address
   */
  function setKeeperRegistryAddress(address _keeperRegistryAddress) external onlyOwner {
    s_keeperRegistryAddress = _keeperRegistryAddress;
  }

  /**
   * @notice Gets the minimum wait period
   */
  function getMinWaitPeriod() public view returns(uint256 minWaitPeriod) {
    return s_minWaitPeriod;
  }

  /**
   * @notice Sets the minimum wait period for addresses between funding
   */
  function setMinWaitPeriod(uint256 _minWaitPeriod) external onlyOwner {
    s_minWaitPeriod = _minWaitPeriod;
  }

  /**
   * @notice Sets the list of addresses to watch and their funding parameters
   * @param _addresses the list of addresses to watch
   * @param _minBalancesWei the minimum balances for each address
   * @param _topUpAmountsWei the amount to top up each address
   */
  function setWatchList(address[] memory _addresses, uint256[] memory _minBalancesWei, uint256[] memory _topUpAmountsWei) external onlyOwner {
    require(_addresses.length == _minBalancesWei.length && _addresses.length == _topUpAmountsWei.length, "all lists must have same length");
    address[] memory oldWatchList = s_watchList;
    address[] memory newWatchList = new address[](_addresses.length);
    for (uint256 idx = 0; idx < oldWatchList.length; idx++) {
      accountConfigs[oldWatchList[idx]].isActive = false;
    }
    for (uint256 idx = 0; idx < _addresses.length; idx++) {
      newWatchList[idx] = _addresses[idx];
      accountConfigs[_addresses[idx]] = Config({
        isActive: true,
        minBalanceWei: _minBalancesWei[idx],
        topUpAmountWei: _topUpAmountsWei[idx],
        lastTopUp: 0
      });
    }
    s_watchList = newWatchList;
  }

  /**
   * @notice Gets the list of addresses being watched
   */
  function getWatchList() public view returns(address[] memory) {
    return s_watchList;
  }

  /**
   * @notice Gets configuration information for an address
   */
  function getAccountInfo(address target) public view
    returns(bool isActive, uint256 minBalanceWei, uint256 topUpAmountWei, uint256 lastTopUp)
  {
    Config memory config = accountConfigs[target];
    return (config.isActive, config.minBalanceWei, config.topUpAmountWei, config.lastTopUp);
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
   * @notice Checks list of addresses for those that require funding
   * @param _checkData unused but needed to conform to keeper API
   * @return upkeepNeeded signals if upkeep is needed, performData is an abi encoded list of addresses that need funds
   */
  function checkUpkeep(bytes calldata _checkData) override view public
    returns (
      bool upkeepNeeded,
      bytes memory performData
    )
  {
    address[] memory watchList = s_watchList;
    address[] memory needsFunding = new address[](watchList.length);
    uint256 count = 0;
    uint256 topUpCost = 0;
    uint256 minWaitPeriod = s_minWaitPeriod;
    uint256 balance = address(this).balance;
    for (uint256 idx = 0; idx < watchList.length; idx++) {
      Config memory config = accountConfigs[watchList[idx]];
      if (
        watchList[idx].balance < config.minBalanceWei &&
        config.lastTopUp + minWaitPeriod <= block.number &&
        balance >= topUpCost + config.topUpAmountWei
      ) {
        needsFunding[count] = watchList[idx];
        count++;
        topUpCost += config.topUpAmountWei;
      }
    }
    if (count != watchList.length) {
      assembly {
        mstore(needsFunding, count)
      }
    }
    bool canPerform = count > 0 && address(this).balance >= topUpCost;
    return (canPerform, abi.encode(needsFunding));
  }

  /**
   * @notice Sends fund to the addresses specified in performData
   * @param _performData The abi encoded list of addresses to fund
   */
  function performUpkeep(bytes calldata _performData) override external whenNotPaused() {
    require(msg.sender == s_keeperRegistryAddress, "only callable by keeper");
    address[] memory needsFunding = abi.decode(_performData, (address[]));
    uint256 minWaitPeriod = s_minWaitPeriod;
    for (uint256 idx = 0; idx < needsFunding.length; idx++) {
      Config memory config = accountConfigs[needsFunding[idx]];
      if (config.isActive &&
        needsFunding[idx].balance < config.minBalanceWei &&
        config.lastTopUp + minWaitPeriod <= block.number
      ) {
        bool success = payable(needsFunding[idx]).send(config.topUpAmountWei);
        if (success) {
          accountConfigs[needsFunding[idx]].lastTopUp = block.number;
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
}
