// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFCoordinatorV2_5.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract MinimalVRFConsumer is VRFConsumerBaseV2Plus {

    VRFV2PlusClient.RandomWordsRequest public requestDetails;
    VRFCoordinatorV2_5 immutable COORDINATOR;
    bytes32 internal immutable keyHash;
    uint256 internal immutable subscriptionId;

    event RandomWordsRequested(uint256 requestId);
    event RandomWordsFulfilled(uint256[] randomWords);

    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2_5(_vrfCoordinator); 
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

   
    function requestRandomWords() external {
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
        emit RandomWordsRequested(block.number);  
    }

    
    function fulfillRandomWords(uint256  requestId , uint256[] calldata randomWords) internal override {
        emit RandomWordsFulfilled(randomWords);  
    }
}
