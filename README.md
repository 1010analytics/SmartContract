
# TaxToken Smart Contract

## Overview
`TaxToken` is a smart contract developed on Ethereum using Solidity. It is designed to handle token transactions with a taxation mechanism, where taxes are collected and distributed to a randomly selected token holder based on their token holdings. This contract ensures automated tax distribution and leverages Chainlink's VRF (Verifiable Random Function) for secure random selection.

## Features
- **Tax Collection**: Implements a fixed tax rate on buy and sell transactions.
- **Automated Tax Distribution**: Uses automation to distribute collected taxes weekly to a randomly selected token holder.
- **Secure Randomness**: Integrates Chainlink VRF to ensure the fairness and verifiability of the random selection process.
- **Non-modifiable Tax Rate**: The tax rate is set at deployment and cannot be changed, ensuring transparency and trust.

## Excluded Features
- No ability to pause the contract.
- No blacklist or whitelist functionalities.
- Tax rate is immutable post-deployment.

## Smart Contract Methods
### Public Functions
- `buyTokens()`: Allows users to buy tokens and automatically pays a tax and a development fee.
- `sellTokens(uint256 amount)`: Allows users to sell tokens with a tax and development fee deducted.

### Automation Functions
- `checkUpkeep()`: Checks if the conditions for performing upkeep (tax distribution) are met.
- `performUpkeep()`: Performs the upkeep task if the conditions are satisfied, distributing the tax collected.

## Setup and Deployment
- The contract should be deployed using Truffle Suite.
- A Chainlink VRF coordinator address and LINK token address are required at deployment for randomness functionality.

## Testing
The smart contract includes tests written using Truffle and OpenZeppelin's test helpers. Tests cover basic functionality such as buying and selling tokens, handling errors, and automated tax distribution.

### Running Tests
```bash
truffle test


