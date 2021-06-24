pragma solidity 0.8.4;

import "../upkeeps/EthBalanceMonitor.sol";

contract EthBalanceMonitorExposed is EthBalanceMonitor {
  constructor(address _keeperRegistryAddress, uint256 _minBalanceWei, uint256 _minWaitPeriod, uint256 _topUpAmountWei)
    EthBalanceMonitor(_keeperRegistryAddress, _minBalanceWei, _minWaitPeriod, _topUpAmountWei)
  {}

  function setLastTopUpXXXTestOnly(address _address, uint256 _lastTopUp) public {
    lastTopUp[_address] = _lastTopUp;
  }
}
