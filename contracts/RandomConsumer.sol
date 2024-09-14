// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ICoordinator} from "./intefaces/ICoordinator.sol";
import "hardhat/console.sol";

contract RandomConsumer {
    address private immutable COORDINATOR;
    uint256 private _subscriptionId;

    uint256 public requestId;
    uint256 public randomWord;

    event RequestSent(uint256 requestId);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event TaskFulfilled(uint256 requestId_, uint256 randomWord_);

    error OnlyCoordinatorCanFulfill();

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256 randomWord;
    }

    mapping(uint256 => RequestStatus) public requests;

    /**
     * @param _coordinator address of VRFCoordinator contract
     */
    constructor(address _coordinator) {
        COORDINATOR = _coordinator;
    }

    function requestRandomNumber() external {
        requests[requestId] = RequestStatus({exists: true, fulfilled: false, randomWord: 0});
        requestId = ICoordinator(COORDINATOR).requestJob(_subscriptionId, ICoordinator.JobType.RANDOM);

        emit RequestSent(requestId);
    }

    // rawFulfillRandomness is called by Coordinator rawFulfillRandomness then calls fulfillRandomness.
    function rawFulfillTask(uint256 requestId_, uint256 randomWord_) external {
        if (msg.sender != COORDINATOR) {
            revert OnlyCoordinatorCanFulfill();
        }

        fulfillTask(requestId_, randomWord_);
    }

    function fulfillTask(uint256 requestId_, uint256 randomWord_) public {
        randomWord = randomWord_;

        emit TaskFulfilled(requestId_, randomWord_);
    }

    function setCoordinatorConifg(uint256 subscriptionId) external {
        _subscriptionId = subscriptionId;
    }
}
