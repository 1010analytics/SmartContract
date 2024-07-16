// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBase.sol";

contract TaxToken is VRFConsumerBase {
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

    event TokensDistributed(address recipient, uint256 amount);

    constructor(
        address _vrfCoordinator, 
        address _linkToken, 
        bytes32 _keyHash, 
        uint256 _fee, 
        address _devWallet
    )
        VRFConsumerBase(_vrfCoordinator, _linkToken) // Initialize the VRFConsumerBase contract
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
        tokenHolders.push(msg.sender);
        payable(devWallet).transfer(devFee);
    }

    
    function sellTokens(uint256 amount) public {
        require(amount > 0, "Cannot sell zero tokens");
        require(tokenBalances[msg.sender] >= amount, "Insufficient balance to sell tokens");
        uint256 tax = amount * BUY_SELL_TAX_PERCENT / 100;
        uint256 devFee = amount * DEV_FEE_PERCENT / 100;
        uint256 amountAfterTax = amount - tax - devFee;
        tokenBalances[msg.sender] -= amount;
        payable(msg.sender).transfer(amountAfterTax);
        payable(devWallet).transfer(devFee);
    }

    
    function requestRandomWinner() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Insufficient LINK to request randomness");
        require(block.timestamp >= lastDistribution + interval, "Distribution too soon");
        requestId = requestRandomness(keyHash, fee);
        requestRandomnessFulfilled[requestId] = true; 
    }

    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(requestRandomnessFulfilled[requestId], "Request not found or already fulfilled");
        address winner = selectRandomWinner(randomness);
        uint256 taxPool = address(this).balance;
        (bool success, ) = payable(winner).call{value: taxPool}("");
        require(success, "Failed to transfer tax to winner");
        emit TokensDistributed(winner, taxPool);
        requestRandomnessFulfilled[requestId] = false; 
        lastDistribution = block.timestamp;
    }

    
    function selectRandomWinner(uint256 randomness) private view returns (address) {
        uint256 totalTokens = 0;
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            totalTokens += tokenBalances[tokenHolders[i]];
        }
        require(totalTokens > 0, "No tokens held by any address");

        uint256 index = randomness % totalTokens;
        uint256 cumulativeSum = 0;
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            cumulativeSum += tokenBalances[tokenHolders[i]];
            if (index < cumulativeSum) {
                return tokenHolders[i];
            }
        }
        revert("Failed to select a winner");
    }
}
