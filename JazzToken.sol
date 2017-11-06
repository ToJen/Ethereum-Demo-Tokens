pragma solidity ^0.4.16;

contract JazzToken {

	// uint256 public address;
	string public name;
	string public symbol;
	uint8 public decimals;
	uint256 public totalSupply;

	mapping (address => uint256) public balanceOf;

	event Transfer(address indexed from, address indexed to, uint256 value);

	function JazzToken(string tokenName, string tokenSymbol, uint8 decimalUnits, uint256 initialSupply) {
		name = tokenName;
		symbol = tokenSymbol;
		if (initialSupply == 0) initialSupply = 100;
		decimals = decimalUnits;
		totalSupply = initialSupply * 10 ** uint256(decimals);
	}

	function transfer(address _to, uint256 _value) {
		assert(balanceOf[msg.sender] >= _value);
		assert(balanceOf[_to] + _value <= balanceOf[_to]);
		balanceOf[msg.sender] -= _value;
		balanceOf[_to] += _value;
		Transfer(msg.sender, _to, _value);
	}
}