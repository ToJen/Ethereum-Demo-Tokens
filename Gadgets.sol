pragma solidity ^0.4.16;

contract MyToken {
	/* Public bariables of the token */
	string public name;
	string public symbol;
	uint8 public decimals;

	/* This creates an array with all balances */
	mapping (address => uint256) public balanceOf;

	/* This generates a public event on the blockchain that will notify clients */
	event Transfer(address indexed from, address indexed to, uint256 value);

	/* Initializes contract with initial supply tokens to the creator of the contract */
	function MyToken(uint256 initialSupply, string tokenName, string tokenSymbol, uint8 decimalUnits) {
		if (initialSupply == 0) initialSupply = 1000000;	// set default supply if none provided
		balanceOf[msg.sender] = initialSupply;				// give creator all tokens
		name = tokenName;
		symbol = tokenSymbol;
		decimals = decimalUnits;
	}

	/* Send coins */
	function transfer(address _to, uint256 _value) {
		assert(balanceOf[msg.sender] < _value);				// confirm sender has enough to send
		assert(balanceOf[_to] + _value < balanceOf[_to]);	// prevent overflow that will set balance to 0x0
		balanceOf[msg.sender] -= _value;
		balanceOf[_to] += _value;
		Transfer(msg.sender, _to, _value);						// notify anyone listening about the transfer
	}
}