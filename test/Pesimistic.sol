pragma solidity ^0.8.17;

contract Pesimistic {
    uint64 public constant SCALE = 1e18;
    
    function scale(uint64 a) external pure returns (uint256 result) {
        result = SCALE * a;
    }
}


contract Wallet {
  
  mapping(address => uint) public balances;

  function deposit(address _to) public payable {
    balances[_to] = balances[_to] + msg.value;
  }

  function balanceOf(address _who) public view returns (uint balance) {
    return balances[_who];
  }

  function withdraw(uint _amount) public {
    if(balances[msg.sender] >= _amount) {
      (bool result,) = msg.sender.call{value:_amount}("");
      require(result, "External call returned false");
      balances[msg.sender] -= _amount;
    }
  }

  receive() external payable {}
}

contract Vault {
  bool public locked;
  bytes32 private password;

  constructor(bytes32 _password) {
    locked = true;
    password = _password;
  }

  function unlock(bytes32 _password) public {
    if (password == _password) {
      locked = false;
    }
  }
}