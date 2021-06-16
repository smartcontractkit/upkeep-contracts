// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../interfaces/KeeperCompatibleInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract EthBalanceMonitor is Ownable, Pausable, KeeperCompatibleInterface {

  struct Config {
    uint256 minBalanceWei;
    uint256 topUpAmountWei;
  }

  address[] private s_watchList;
  mapping (address=>bool) private activeAddresses;
  Config private s_config;
  address public keeperRegistryAddress;

  constructor(address _keeperRegistryAddress, uint256 minBalanceWei, uint256 topUpAmountWei) {
    keeperRegistryAddress = _keeperRegistryAddress;
    _setConfig(minBalanceWei, topUpAmountWei);
  }

  receive() external payable {}

  function withdraw(uint256 _amount, address payable _payee) external onlyOwner {
    _payee.transfer(_amount);
  }

  function setConfig(uint256 _minBalanceWei, uint256 _topUpAmountWei) external onlyOwner {
    _setConfig(_minBalanceWei, _topUpAmountWei);
  }

  function getConfig() public view returns(uint256 minBalanceWei, uint256 topUpAmountWei) {
    Config memory config = s_config;
    return (config.minBalanceWei, config.topUpAmountWei);
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
      if (watchList[idx].balance < config.minBalanceWei) {
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
    address[] memory needsFunding = abi.decode(_performData, (address[]));
    Config memory config = s_config;
    if (address(this).balance < needsFunding.length * config.topUpAmountWei) {
      revert("not enough eth to fund all addresses");
    }
    for (uint256 idx = 0; idx < needsFunding.length; idx++) {
      if (activeAddresses[needsFunding[idx]] && needsFunding[idx].balance < config.minBalanceWei) {
        payable(needsFunding[idx]).transfer(config.topUpAmountWei);
      }
    }
  }

  function _setConfig(uint256 _minBalanceWei, uint256 _topUpAmountWei) internal {
    Config memory config = Config({
      minBalanceWei: _minBalanceWei,
      topUpAmountWei: _topUpAmountWei
    });
    s_config = config;
  }
}
