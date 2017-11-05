pragma solidity ^0.4.16;

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }

contract owned {
    address public owner;
    
    function owned() {
        owner = msg.sender;
    }
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract MyToken is owned {
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function MyToken(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol,
        address centralMinter
    ) public {
        if(centralMinter != 0) owner = centralMinter;
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                // Give the creator all initial tokens
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
        timeOfLastProof = now;                              // maintain reasonable level of difficulty
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] >= _value);
        // Check for overflows
        require(balanceOf[_to] + _value > balanceOf[_to]);
        // Check if sender is frozen
        require(approvedAccount[_from]);
        // Check if recipient is frozen
        require(approvedAccount[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        // Subtract from the sender
        balanceOf[_from] -= _value;
        // Add the same to the recipient
        balanceOf[_to] += _value;
        Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public {
        require(approvedAccount[msg.sender]);
        if(msg.sender.balance < minBalanceForAccounts)
            sell((minBalanceForAccounts - msg.sender.balance) / sellPrice);

        // make receiver pay for transaction after ensuring they have enough
        // if(_to.balance < minBalanceForAccounts)
        //     _to.send(sell((minBalanceForAccounts - _to.balance) / sellPrice));

        _transfer(msg.sender, _to, _value);
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` in behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);     // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        public
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
        balanceOf[msg.sender] -= _value;            // Subtract from the sender
        totalSupply -= _value;                      // Updates totalSupply
        Burn(msg.sender, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] -= _value;                         // Subtract from the targeted balance
        allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
        totalSupply -= _value;                              // Update totalSupply
        Burn(_from, _value);
        return true;
    }
    
    /**
     * Enable owner to create new tokens
     * 
     * Increments balance of `target` by `mintedAmount`
     * 
     * @param target the address containing the total supply
     * @param mintedAmount the amount of newly minted tokens
     */
    function mintToken(address target, uint256 mintedAmount) onlyOwner {
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, owner, mintedAmount);
        Transfer(owner, target, mintedAmount);
    }
    
    mapping (address => bool) public approvedAccount;
    event FrozenFunds(address target, bool frozen);
    
    /**
     * Freeze or unfreeze an account
     * 
     * Sets the state of `target` according to `freeze`

     * @param target the address to freeze or release
     * @param freeze to determing the frozen state of `target`
     */
    function approvedAccount(address target, bool freeze) onlyOwner {
        approvedAccount[target] = freeze;
        FrozenFunds(target, freeze);    // notify anyone listening that target has been frozen
    }


    uint256 public sellPrice;
    uint256 public buyPrice;

    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }
    
    function buy() payable returns (uint amount) {
        amount = msg.value / buyPrice;          // calculates the amount
        require(balanceOf[this] >= amount);     // checks if it has enough to sell
        balanceOf[msg.sender] += amount;        // adds the amount to buyer's balance
        balanceOf[this] -= amount;              // deducts amount from sellers balance
        Transfer(this, msg.sender, amount);     // execute an event reflecting the change
        return amount;
    }

    function sell(uint amount) returns (uint revenue) {
        require(balanceOf[msg.sender] >= amount);     // ensure sender is loaded enough
        balanceOf[this] += amount;                  // adds amount to owner's balance
        balanceOf[msg.sender] -= amount;            // deducts from seller's balance
        revenue = amount * sellPrice;
        require(msg.sender.send(revenue));          // sends ether to seller: this prevents recursion attacks
        Transfer(msg.sender, this, amount);         // executes an event reflecting on the change
        return revenue;

    }


    /*
    uint minBalanceForAccounts;


    function setMinBalance(uint minimumBalanceInFinney) onlyOwner {
        minBalanceForAccounts = minBalanceForAccounts * 1 finney;
    }

    function giveBlockReward() {
        balanceOf[block.coinbase] += 1;
    }

    uint currentChallenge = 1;      // can you figure out the cubic root of this numer?

    function rewardMathGeniuses(uint answerToCurrentReward, uint nextChallenge) {
        require(answerToCurrentReward**3 == currentChallenge);  // if answer is incorrect, do not continue
        balanceOf[msg.sender] += 1;                             // reward the player
        currentChallenge = nextChallenge;                       // set the next next challenge
    }
    */


    bytes32 public currentChallenge;        // the coin starts with a challenge
    uint public timeOfLastProof;            // keep track of when rewards were given
    uint public difficulty = 10**32;        // difficulty starts reasonably low

    function proofOfWork(uint nonce) {
        bytes8 n = bytes8(sha3(nonce, currentChallenge));        // generate random hash based on input
        require(n >= bytes8(difficulty));                       // check if it is under the difficulty

        uint timeSinceLastProof = (now -timeOfLastProof);       // calculate time since last reward was given
        require(timeSinceLastProof >= 5 seconds);               // rewards cannot be given too quickly
        balanceOf[msg.sender] += timeSinceLastProof / 60 seconds;   // reward to the winner grows by minute

        difficulty = difficulty *10 minutes / timeSinceLastProof + 1;   // adjust the difficulty

        timeOfLastProof = now;  // reset the counter
        currentChallenge = sha3(nonce, currentChallenge, block.blockhash(block.number - 1)); // save a hash that will be used as the next proof
    }
}
