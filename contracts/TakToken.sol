// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IVRFConsumer {
    function requestRandomWinner() external;
}

contract TaxToken is ERC20, Ownable {

    address public immutable devWallet;
    address public immutable prizeWallet;

    uint256 public constant buySellTaxRate = 19;
    uint256 public constant devTaxRate = 1;

    uint256 public prizePool;
    uint256 public constant totalSupplyTokens = 1000000 * 10**18;
    uint256 public constant minimumPrizePool = 10 * 10**18;

    uint256 public totalWeight;
    mapping(address => uint256) public holderWeights;
    address[] public holders;

    IVRFConsumer public vrfConsumer; 

    event HolderUpdated(address indexed holder, uint256 newWeight);
    event TaxesCollected(address from, uint256 taxAmount, uint256 devAmount);
    bool public emergencyActive = false;

    constructor(
        address _vrfConsumer,  
        address _devWallet,
        address _prizeWallet
    ) ERC20("TaxToken", "TTK") Ownable(msg.sender) {
        devWallet = _devWallet;
        prizeWallet = _prizeWallet;
        vrfConsumer = IVRFConsumer(_vrfConsumer);  
        _mint(msg.sender, totalSupplyTokens);
    }

    
    function updateVRFConsumer(address newVrfConsumer) external onlyOwner {
        require(newVrfConsumer != address(0), "Invalid address");
        vrfConsumer = IVRFConsumer(newVrfConsumer);
    }

    function taxedTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        uint256 taxAmount = (amount * buySellTaxRate) / 100;
        uint256 devAmount = (amount * devTaxRate) / 100;
        uint256 transferAmount = amount - taxAmount - devAmount;

        _transfer(sender, prizeWallet, taxAmount);
        _transfer(sender, devWallet, devAmount);

        prizePool += taxAmount;
        _transfer(sender, recipient, transferAmount);

        updateHolderWeight(sender);
        updateHolderWeight(recipient);
        emit TaxesCollected(sender, taxAmount, devAmount);
    }

    function transferWithTax(address recipient, uint256 amount) external {
        taxedTransfer(msg.sender, recipient, amount);
    }

    
    function updateHolderWeight(address holder) internal {
        uint256 previousWeight = holderWeights[holder];
        uint256 newWeight = balanceOf(holder) / 1000;

        if (previousWeight != newWeight) {
            totalWeight = totalWeight - previousWeight + newWeight;
            holderWeights[holder] = newWeight;

            if (newWeight > 0 && previousWeight == 0) {
                holders.push(holder);
            } else if (newWeight == 0) {
                removeFromHolders(holder);
            }
            emit HolderUpdated(holder, newWeight);
        }
    }

    function removeFromHolders(address holder) internal {
        uint256 index;
        for (index = 0; index < holders.length; index++) {
            if (holders[index] == holder) {
                break;
            }
        }
        holders[index] = holders[holders.length - 1];
        holders.pop();
    }

    
    function requestRandomWinnerFromVRF() external onlyOwner {
        require(prizePool >= minimumPrizePool, "Prize pool too low");
        vrfConsumer.requestRandomWinner();
    }

    
    function triggerEmergency() external onlyOwner {
        emergencyActive = true;
    }

    
    function emergencyWithdraw(address to) external onlyOwner {
        require(emergencyActive, "Emergency is not active, withdrawal not allowed");
        uint256 balance = balanceOf(prizeWallet);
        _transfer(prizeWallet, to, balance);
        emergencyActive = false;
    }

    
    function lockPrizeFunds() external onlyOwner {
        _approve(prizeWallet, address(this), balanceOf(prizeWallet));
        require(balanceOf(prizeWallet) > 0, "No funds in prize wallet");
    }
}
