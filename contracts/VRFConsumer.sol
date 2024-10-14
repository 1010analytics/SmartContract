// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFCoordinatorV2_5.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

interface ITaxToken {
    function selectRandomWinner(uint256 randomness) external;
}

contract VRFConsumer is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    VRFV2PlusClient.RandomWordsRequest public requestDetails;
    ITaxToken public taxToken;  

    VRFCoordinatorV2_5 immutable COORDINATOR;
    bytes32 internal immutable keyHash;
    uint256 internal immutable subscriptionId;

    uint256 public lastUpkeepTimestamp;
    uint256 public constant interval = 7 days;

    event RandomWordsRequested(uint256 requestId);
    event RandomWordsFulfilled(uint256[] randomWords);

    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        address _taxToken
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2_5(_vrfCoordinator); 
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        taxToken = ITaxToken(_taxToken);  
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - lastUpkeepTimestamp) > interval;
        return (upkeepNeeded, bytes(""));
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if ((block.timestamp - lastUpkeepTimestamp) > interval) {
            requestRandomWinner();
            lastUpkeepTimestamp = block.timestamp;
        }
    }

    function requestRandomWinner() internal {
        requestDetails = VRFV2PlusClient.RandomWordsRequest({
            keyHash: keyHash,
            subId: subscriptionId,
            requestConfirmations: 3,
            callbackGasLimit: 2500000,
            numWords: 1,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        COORDINATOR.requestRandomWords(requestDetails);
    }

    function fulfillRandomWords(uint256  requestId , uint256[] calldata randomWords) internal override {
        taxToken.selectRandomWinner(randomWords[0]);  
        emit RandomWordsFulfilled(randomWords);
    }
}
