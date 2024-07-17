// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract TaxToken is VRFConsumerBase, ReentrancyGuard, AutomationCompatible {
    uint256 public constant BUY_SELL_TAX_PERCENT = 19;
    uint256 public constant DEV_FEE_PERCENT = 1;
    address public devWallet;
    address[] public tokenHolders;
    mapping(address => uint256) public tokenBalances;
    mapping(bytes32 => bool) private requestRandomnessFulfilled;
    uint256 public lastDistribution;
    uint256 public interval = 7 days;  
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public totalTaxCollected;  

    event TokensDistributed(address recipient, uint256 amount);

    constructor(
        address _vrfCoordinator, 
        address _linkToken, 
        bytes32 _keyHash, 
        uint256 _fee, 
        address _devWallet
    )
        VRFConsumerBase(_vrfCoordinator, _linkToken)
    {
        keyHash = _keyHash;
        fee = _fee;
        devWallet = _devWallet;
        lastDistribution = block.timestamp;
    }

    function buyTokens() public payable {
        require(msg.value > 0, "Cannot buy with zero value");
        uint256 tax = msg.value * BUY_SELL_TAX_PERCENT / 100;
        uint256 devFee = msg.value * DEV_FEE_PERCENT / 100;
        uint256 tokensToMint = msg.value - tax - devFee;

        tokenBalances[msg.sender] += tokensToMint;
        totalTaxCollected += tax;
        if (!isTokenHolder(msg.sender)) {
            tokenHolders.push(msg.sender);
        }
        payable(devWallet).transfer(devFee);
    }

    function sellTokens(uint256 amount) public nonReentrant {
        require(amount > 0, "Cannot sell zero tokens");
        require(tokenBalances[msg.sender] >= amount, "Insufficient balance to sell tokens");

        uint256 tax = amount * BUY_SELL_TAX_PERCENT / 100;
        uint256 devFee = amount * DEV_FEE_PERCENT / 100;
        uint256 amountAfterTax = amount - tax - devFee;

        tokenBalances[msg.sender] -= amount;
        totalTaxCollected += tax;
        payable(msg.sender).transfer(amountAfterTax);
        payable(devWallet).transfer(devFee);
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp >= lastDistribution + interval) && (totalTaxCollected > 0);
        performData = "";  // Not used
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        require((block.timestamp >= lastDistribution + interval) && (totalTaxCollected > 0), "Upkeep not needed");
        distributeTax();
    }

    function distributeTax() internal {
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
        requestRandomnessFulfilled[requestId] = false;
    }

    function selectRandomWinner(uint256 randomness) private view returns (address) {
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            totalWeight += tokenBalances[tokenHolders[i]];
        }
        require(totalWeight > 0, "No tokens held by any address");

        uint256 randomWeight = randomness % totalWeight;
        uint256 cumulativeWeight = 0;
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            cumulativeWeight += tokenBalances[tokenHolders[i]];
            if (randomWeight < cumulativeWeight) {
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
}
