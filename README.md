# Smart Contract with Taxation and Random Distribution Mechanism

This project is a smart contract developed on the Ethereum blockchain using Solidity. The contract is designed to manage token transactions with an integrated taxation mechanism. Taxes collected from token transfers are pooled and later distributed to a randomly selected token holder, where the probability of selection is based on their token holdings. To ensure secure and verifiable randomness, the contract utilizes **Chainlink's Verifiable Random Function (VRF)**.

## Key Features

- **Token Transactions with Taxation**: A percentage of every token transfer is taxed and added to a prize pool.
- **Automated Tax Distribution**: Taxes are automatically distributed to a randomly selected token holder based on their holdings.
- **Secure Random Selection**: The contract uses Chainlink's VRF to ensure that the selection of the prize recipient is truly random and secure.

## Development Challenges

During the development of this contract, we encountered a **compiler version mismatch** issue. Specifically:

- One dependency was incompatible with compiler versions higher than `0.8.19`.
- Two other dependencies required compiler versions `0.8.20` or higher.

To resolve this, we split the contract into two separate contracts:

1. **Token Contract**:

   - Handles token logic, tax collection, holder weights, and manages the prize pool.
   - Knows how to select the wallet for tax distribution but does not generate randomness.

2. **VRF Consumer Contract**:
   - Interacts with **Chainlink's VRF** to generate randomness.
   - Generates a random number but does not know how to select the wallet for tax distribution.

These contracts are connected via **interfacing**, allowing them to make **cross-contract calls**. The VRF Consumer contract generates the random number, and the Token contract handles the wallet selection logic.

## Current Roadblocks

I’m currently facing an issue while trying to **fulfill Chainlink VRF requests**. After deploying the contracts and adding the VRF Consumer as a subscriber in the Chainlink VRF subscription, I’m unable to call the randomness function. The gas estimation fails, and the transaction does not go through.

### VRF Isolation Code

To isolate the issue, I wrote and tested a simple VRF contract that interacts with Chainlink's VRF without any additional logic. This **isolated contract** worked as expected—I was able to request and receive a random number. The code for this is included in the repository.
