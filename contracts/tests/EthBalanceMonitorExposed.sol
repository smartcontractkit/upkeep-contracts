pragma solidity 0.8.6;

import "../upkeeps/EthBalanceMonitor.sol";

contract EthBalanceMonitorExposed is EthBalanceMonitor {
  constructor(address _keeperRegistryAddress, uint256 _minWaitPeriod)
    EthBalanceMonitor(_keeperRegistryAddress, _minWaitPeriod)
  {}

  function setLastTopUpXXXTestOnly(address _address, uint256 _lastTopUp) public {
    accountConfigs[_address].lastTopUp = _lastTopUp;
  }
}
