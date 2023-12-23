pragma solidity ^0.8.17;

contract Pesimistic {
    uint64 public constant SCALE = 1e18;
    
    function scale(uint64 a) external pure returns (uint256 result) {
        result = SCALE * a;
    }
}

