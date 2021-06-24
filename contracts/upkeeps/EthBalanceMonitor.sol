// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../interfaces/KeeperCompatibleInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract EthBalanceMonitor is Ownable, Pausable, KeeperCompatibleInterface {

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
    uint256 minBalanceWei;
    uint256 minWaitPeriod;
    uint256 topUpAmountWei;
  }

  address public keeperRegistryAddress;
  address[] private s_watchList;
  Config private s_config;
  mapping (address=>bool) private activeAddresses;
  mapping (address=>uint256) internal lastTopUp;

  constructor(address _keeperRegistryAddress, uint256 _minBalanceWei, uint256 _minWaitPeriod, uint256 _topUpAmountWei) {
    keeperRegistryAddress = _keeperRegistryAddress;
    _setConfig(_minBalanceWei, _minWaitPeriod, _topUpAmountWei);
  }

  receive() external payable {
    emit FundsAdded(address(this).balance);
  }

  function withdraw(uint256 _amount, address payable _payee) external onlyOwner {
    _payee.transfer(_amount);
  }

  function setConfig(uint256 _minBalanceWei, uint256 _minWaitPeriod, uint256 _topUpAmountWei) external onlyOwner {
    _setConfig(_minBalanceWei, _minWaitPeriod, _topUpAmountWei);
  }

  function getConfig() public view returns(uint256 minBalanceWei, uint256 minWaitPeriod, uint256 topUpAmountWei) {
    Config memory config = s_config;
    return (config.minBalanceWei, config.minWaitPeriod, config.topUpAmountWei);
  }

  function setWatchList(address[] memory _watchList) external onlyOwner {
    address[] memory watchList = s_watchList;
    for (uint256 idx = 0; idx < watchList.length; idx++) {
      activeAddresses[watchList[idx]] = false;
    }
    for (uint256 idx = 0; idx < _watchList.length; idx++) {
      activeAddresses[_watchList[idx]] = true;
    }
    s_watchList = _watchList;
  }

  function getWatchList() public view returns(address[] memory) {
    return s_watchList;
  }

  function isActive(address _address) public view returns(bool) {
    return activeAddresses[_address];
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function checkUpkeep(bytes calldata _checkData) override view public
    returns (
      bool upkeepNeeded,
      bytes memory performData
    )
  {
    Config memory config = s_config;
    address[] memory watchList = s_watchList;
    address[] memory needsFunding = new address[](watchList.length);
    uint256 count = 0;
    for (uint256 idx = 0; idx < watchList.length; idx++) {
      if (watchList[idx].balance < config.minBalanceWei && lastTopUp[watchList[idx]] + config.minWaitPeriod <= block.number) {
        needsFunding[count] = watchList[idx];
        count++;
      }
    }
    if (count != watchList.length) {
      assembly {
        mstore(needsFunding, count)
      }
    }
    bool canPerform = count > 0 && address(this).balance >= count * config.topUpAmountWei;
    return (canPerform, abi.encode(needsFunding));
  }

  function performUpkeep(bytes calldata _performData) override external whenNotPaused() {
    require(msg.sender == keeperRegistryAddress, "only callable by keeper");
    address[] memory needsFunding = abi.decode(_performData, (address[]));
    Config memory config = s_config;
    if (address(this).balance < needsFunding.length * config.topUpAmountWei) {
      revert("not enough eth to fund all addresses");
    }
    for (uint256 idx = 0; idx < needsFunding.length; idx++) {
      if (activeAddresses[needsFunding[idx]] &&
        needsFunding[idx].balance < config.minBalanceWei &&
        lastTopUp[needsFunding[idx]] + config.minWaitPeriod <= block.number
      ) {
        bool success = payable(needsFunding[idx]).send(config.topUpAmountWei);
        if (success) {
          lastTopUp[needsFunding[idx]] = block.number;
          emit TopUpSucceeded(address(this));
        } else {
          emit TopUpFailed(address(this));
        }
      }
    }
  }

  function _setConfig(uint256 _minBalanceWei, uint256 _minWaitPeriod, uint256 _topUpAmountWei) internal {
    Config memory config = Config({
      minBalanceWei: _minBalanceWei,
      minWaitPeriod: _minWaitPeriod,
      topUpAmountWei: _topUpAmountWei
    });
    s_config = config;
  }
}
