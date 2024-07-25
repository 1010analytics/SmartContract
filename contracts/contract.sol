// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract TaxToken is VRFConsumerBase, ReentrancyGuard, AutomationCompatible {
    uint256 public constant BUY_SELL_TAX_PERCENT = 19;
    uint256 public constant DEV_FEE_PERCENT = 1;
    uint256 public constant TOKEN_INITIAL_PRICE = 0.01 ether; 
    address public devWallet;
    address public prizeWallet;
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
        address _devWallet,
        address _prizeWallet
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        keyHash = _keyHash;
        fee = _fee;
        devWallet = _devWallet;
        prizeWallet = _prizeWallet;
        lastDistribution = block.timestamp;
    }

    function buyTokens() public payable {
        require(msg.value >= TOKEN_INITIAL_PRICE, "Minimum token purchase price not met");
        uint256 tax = calculateTax(msg.value);
        uint256 devFee = calculateDevFee(msg.value);
        uint256 tokensToMint = (msg.value - tax - devFee) / TOKEN_INITIAL_PRICE;

        tokenBalances[msg.sender] += tokensToMint;
        totalTaxCollected += tax;
        if (!isTokenHolder(msg.sender)) {
            tokenHolders.push(msg.sender);
        }
        payable(devWallet).transfer(devFee);
        payable(prizeWallet).transfer(tax);
    }

    function sellTokens(uint256 amount) public nonReentrant {
        require(amount > 0, "Cannot sell zero tokens");
        require(tokenBalances[msg.sender] >= amount, "Insufficient balance to sell tokens");

        uint256 totalValue = amount * TOKEN_INITIAL_PRICE;
        uint256 tax = calculateTax(totalValue);
        uint256 devFee = calculateDevFee(totalValue);
        uint256 amountAfterTax = totalValue - tax - devFee;

        tokenBalances[msg.sender] -= amount;
        totalTaxCollected += tax;
        payable(msg.sender).transfer(amountAfterTax);
        payable(devWallet).transfer(devFee);
        payable(prizeWallet).transfer(tax);
    }

    function checkUpkeep(bytes calldata ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp >= lastDistribution + interval) && (totalTaxCollected > 0) && (LINK.balanceOf(address(this)) >= fee);
        performData = ""; 
    }

    function performUpkeep(bytes calldata ) external override {
        require((block.timestamp >= lastDistribution + interval) && (totalTaxCollected > 0), "Upkeep not needed");
        distributeTax();
    }

    function distributeTax() internal {
        require(LINK.balanceOf(address(this)) >= fee, "Insufficient LINK to request randomness");
        bytes32 requestId = requestRandomness(keyHash, fee);
        requestRandomnessFulfilled[requestId] = true;
        lastDistribution = block.timestamp;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(requestRandomnessFulfilled[requestId], "Request not found or already fulfilled");
        address winner = selectRandomWinner(randomness);
        uint256 taxPool = totalTaxCollected;
        (bool success, ) = payable(winner).call{value: taxPool}("");
        require(success, "Failed to transfer tax to winner");
        emit TokensDistributed(winner, taxPool);
        totalTaxCollected = 0; 
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
}
