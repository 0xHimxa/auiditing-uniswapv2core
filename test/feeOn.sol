// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

contract FeeOnTransferToken {
    // Token metadata
    string public name = "Fee Token";
    string public symbol = "FEE";
    uint8 public decimals = 18;
    
    // Total supply
    uint256 public totalSupply;
    
    // Balances mapping
    mapping(address => uint256) public balanceOf;
    
    // Allowance mapping for approvals
    mapping(address => mapping(address => uint256)) public allowance;
    
    // Fee configuration
    address public feeWallet;
    uint256 public feePercent; // In basis points (1% = 100, 0.5% = 50)
    uint256 public constant BASIS_POINTS = 10000;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event FeeWalletUpdated(address indexed newFeeWallet);
    event FeePercentUpdated(uint256 newFeePercent);
    
    // Constructor - sets initial supply, fee wallet, and fee percentage
    constructor(
        uint256 _initialSupply,
        address _feeWallet,
        uint256 _feePercent
    ) {
        require(_feeWallet != address(0), "Fee wallet cannot be zero address");
        require(_feePercent <= 500, "Fee cannot exceed 5%"); // Max 5% fee
        
        totalSupply = _initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        feeWallet = _feeWallet;
        feePercent = _feePercent;
        
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    // Transfer function with fee
    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    // Transfer from (for approved spenders)
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        require(allowance[sender][msg.sender] >= amount, "Insufficient allowance");
        
        allowance[sender][msg.sender] -= amount;
        _transfer(sender, recipient, amount);
        
        return true;
    }
    
    // Approve spender
    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "Spender cannot be zero address");
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    // Internal transfer function with fee logic
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "Sender cannot be zero address");
        require(recipient != address(0), "Recipient cannot be zero address");
        require(balanceOf[sender] >= amount, "Insufficient balance");
        
        // Calculate fee
        uint256 fee = (amount * feePercent) / BASIS_POINTS;
        uint256 transferAmount = amount - fee;
        
        // Update balances
        balanceOf[sender] -= amount;
        
        // If fee > 0, send to fee wallet
        if (fee > 0) {
            balanceOf[feeWallet] += fee;
            emit Transfer(sender, feeWallet, fee);
        }
        
        // Send remaining to recipient
        balanceOf[recipient] += transferAmount;
        emit Transfer(sender, recipient, transferAmount);
    }
    
    // View functions
    function getFeeAmount(uint256 amount) external view returns (uint256) {
        return (amount * feePercent) / BASIS_POINTS;
    }
    
    // Admin functions (only owner can call these)
    address public owner;
    

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    function updateFeeWallet(address newFeeWallet) external onlyOwner {
        require(newFeeWallet != address(0), "Fee wallet cannot be zero address");
        feeWallet = newFeeWallet;
        emit FeeWalletUpdated(newFeeWallet);
    }
    
    function updateFeePercent(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 500, "Fee cannot exceed 5%");
        feePercent = newFeePercent;
        emit FeePercentUpdated(newFeePercent);
    }
    
    // Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}