// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";


contract PrizeVault {
    address private owner;

    constructor(address _owner) {
        owner = _owner;
    }

    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    
    function releasePrize(address payable recipient, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient funds in vault");
        (bool sent, ) = recipient.call{value: amount}("");
        require(sent, "Failed to send prize");
    }

    
    function emergencyWithdraw(address payable recipient, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient funds");
        (bool sent, ) = recipient.call{value: amount}("");
        require(sent, "Failed to send emergency funds");
    }

    
    receive() external payable {}
}


contract TaxToken is VRFConsumerBase, ReentrancyGuard, AutomationCompatible {
    uint256 public constant BUY_SELL_TAX_PERCENT = 19;
    uint256 public constant DEV_FEE_PERCENT = 1;
    uint256 public constant TOKEN_INITIAL_PRICE = 0.01 ether;
    uint256 public totalTokenSupply;
    address public devWallet;
    PrizeVault public prizeVault;
    address[] public tokenHolders;
    mapping(address => uint256) public tokenBalances;
    mapping(bytes32 => bool) public requestRandomnessFulfilled;
    uint256 public lastDistribution;
    uint256 public interval = 7 days;
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public totalTaxCollected;

    event TokensDistributed(address indexed recipient, uint256 amount);

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee,
        address _devWallet
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        keyHash = _keyHash;
        fee = _fee;
        devWallet = _devWallet;
        prizeVault = new PrizeVault(address(this));
        totalTokenSupply = 0;
    }

    function buyTokens() public payable nonReentrant {
        require(msg.value >= TOKEN_INITIAL_PRICE, "Minimum token purchase price not met");
        uint256 tax = calculateTax(msg.value);
        uint256 devFee = calculateDevFee(msg.value);
        uint256 tokensToMint = (msg.value - tax - devFee) / TOKEN_INITIAL_PRICE;

        tokenBalances[msg.sender] += tokensToMint;
        totalTokenSupply += tokensToMint;
        totalTaxCollected += tax;
        if (!isTokenHolder(msg.sender)) {
            tokenHolders.push(msg.sender);
        }
        payable(devWallet).transfer(devFee);
        prizeVault.releasePrize{value: tax}(payable(address(prizeVault)), tax);
    }

    function sellTokens(uint256 amount) public nonReentrant {
        require(amount > 0, "Cannot sell zero tokens");
        require(tokenBalances[msg.sender] >= amount, "Insufficient balance to sell tokens");

        uint256 totalValue = amount * TOKEN_INITIAL_PRICE;
        uint256 tax = calculateTax(totalValue);
        uint256 devFee = calculateDevFee(totalValue);
        uint256 amountAfterTax = totalValue - tax - devFee;

        tokenBalances[msg.sender] -= amount;
        totalTokenSupply -= amount;
        totalTaxCollected += tax;
        payable(msg.sender).transfer(amountAfterTax);
        payable(devWallet).transfer(devFee);
        prizeVault.releasePrize{value: tax}(payable(address(prizeVault)), tax);
    }

    function isTokenHolder(address candidate) private view returns (bool) {
        for (uint i = 0; i < tokenHolders.length; i++) {
            if (tokenHolders[i] == candidate) {
                return true;
            }
        }
        return false;
    }

    function calculateTax(uint256 amount) private pure returns (uint256) {
        return amount * BUY_SELL_TAX_PERCENT / 100;
    }

    function calculateDevFee(uint256 amount) private pure returns (uint256) {
        return amount * DEV_FEE_PERCENT / 100;
    }

    function selectRandomWinner(uint256 randomness) private view returns (address) {
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            totalWeight += tokenBalances[tokenHolders[i]] / 1000;
            if (randomness % totalWeight < tokenBalances[tokenHolders[i]] / 1000) {
                return tokenHolders[i];
            }
        }
        revert("Failed to select a winner");
    }
}
