pragma solidity 0.8.4;

contract ReceiveReverter {
  receive() external payable {
    revert("Can't send funds");
  }
}
