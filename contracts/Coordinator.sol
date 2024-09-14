// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

import {ICoordinator} from "./intefaces/ICoordinator.sol";
import {VRF} from "./lib/VRF.sol";

contract Coordinator is ICoordinator, VRF, Ownable2StepUpgradeable, UUPSUpgradeable {
    using ECDSAUpgradeable for bytes32;

    uint16 public constant MAX_CONSUMERS = 100;

    uint256 private _currentSubId;

    /// @dev Authorized computer.
    mapping(address => bool) public authorizedComputer;

    /// @dev Track the subscription info by subId.
    mapping(uint256 => Subscription) public subIdToSubscription;

    /// @dev Track the Job info by requestId.
    mapping(uint256 => Job) public requestToJob;

    /// @dev Record the request number of the consumer in one subscription.
    mapping(address => mapping(uint256 => uint256)) public consumerNonce; // consumer->subId->nonce

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function initialize() public initializer {
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
    }

    modifier onlySubscriber(uint256 subId) {
        if (msg.sender != subIdToSubscription[subId].subscriber) {
            revert InvalidSubscriber();
        }
        _;
    }

    /**
     * @notice create a subscription.
     */
    function createSubscription() external {
        //avoid read storage frequently.
        uint256 currentSubId = _currentSubId;

        subIdToSubscription[currentSubId] =
            Subscription({subscriber: msg.sender, balance: 0, active: true, consumers: new address[](0)});

        _currentSubId++;

        emit SubscriptionCreated(currentSubId, msg.sender);
    }

    /**
     * @notice cancel a subscription, can only by the owner of the subscrition.
     */
    function cancelSubscription(uint256 subId) external onlySubscriber(subId) {
        if (subIdToSubscription[subId].subscriber != msg.sender) {
            revert NoActiveSubscription();
        }

        uint256 refund = subIdToSubscription[subId].balance;

        delete subIdToSubscription[subId];

        //refund
        if (refund > 0) {
            SafeTransferLib.safeTransferETH(msg.sender, refund);
        }

        emit SubscriptionCancelled(subId);
    }

    function fundSubscription(uint256 subId) external payable {
        //todo finish the logic of fund.
    }
    /**
     * @notice add consumer for subscription.
     *
     * @param subId        The subscription identifier.
     * @param consumer     The consumer that want to be added.
     */

    function addConsumer(uint256 subId, address consumer) external onlySubscriber(subId) {
        // Already maxed, cannot add any more consumers.
        if (subIdToSubscription[subId].consumers.length == MAX_CONSUMERS) {
            revert TooManyConsumers();
        }

        // Ensures uniqueness in consumerNonce[subId].consumers.
        if (consumerNonce[consumer][subId] != 0) {
            revert ExistedConsumer();
        }

        // Initialize the nonce to 1, indicating the consumer is allocated.
        consumerNonce[consumer][subId] = 1;
        subIdToSubscription[subId].consumers.push(consumer);

        emit SubscriptionConsumerAdded(subId, consumer);
    }

    /**
     * @notice remove consumer for subscription.can only by the owner of the subscrition.
     *
     * @param subId        The subscription identifier.
     * @param consumer     The consumer that want to be removed.
     */
    function removeConsumer(uint64 subId, address consumer) external onlySubscriber(subId) {
        if (consumerNonce[consumer][subId] == 0) {
            revert InvalidConsumer();
        }

        address[] memory consumers = subIdToSubscription[subId].consumers;
        uint256 lastConsumerIndex = consumers.length - 1;
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == consumer) {
                address last = consumers[lastConsumerIndex];
                // Storage write to preserve last element
                subIdToSubscription[subId].consumers[i] = last;
                // Storage remove last element
                subIdToSubscription[subId].consumers.pop();
                break;
            }
        }
        delete consumerNonce[consumer][subId];

        emit SubscriptionConsumerRemoved(subId, consumer);
    }

    /**
     * @notice Request the job from consumer.
     *
     * @param subId        The subscription identifier.
     * @param jobType      The type of the job.
     */
    function requestJob(uint256 subId, JobType jobType) external returns (uint256) {
        if (subIdToSubscription[subId].subscriber == address(0)) {
            revert InvalidSubscription();
        }
        uint256 nonce = consumerNonce[msg.sender][subId];

        if (nonce == 0) {
            revert InvalidConsumer();
        }
        uint256 requestId = _computeRequestId(msg.sender, subId, nonce);
        consumerNonce[msg.sender][subId] = nonce + 1;
        requestToJob[requestId] = Job({requestId: requestId, sender: msg.sender, jobType: jobType});

        emit JobRequest(subId, requestId, msg.sender, jobType);
        return requestId;
    }

    /**
     * @notice fulfill a random number job.
     *
     * @param requestId    The request identifier.
     * @param result       The computation result from offchain.
     * @param signature    The signature that from a authorized computer party.
     */
    function fulfillJobForRandom(uint256 requestId, bytes calldata result, bytes calldata signature) external {
        //check if the result is compute from authorized offchian source.
        _validateResult(result, signature);

        //get requestId and random number,
        //(uint256 requestId, uint256 randomNum) = _getRandomnessFromProof(proof,rc);

        if (requestToJob[requestId].jobType != JobType.RANDOM) {
            revert InvalidJobType();
        }

        address consumer = requestToJob[requestId].sender;
        uint256 randomNum = abi.decode(result, (uint256));

        //call consumer
        (bool success,) =
            consumer.call(abi.encodeWithSignature("rawFulfillTask(uint256,uint256)", requestId, randomNum));
        if (!success) {
            revert JobFailed();
        }
        emit JobForRandomFulfilled(requestId, success);
    }

    /**
     * @notice fulfill a simple job.
     *
     * @param requestId    The request identifier.
     * @param result       The computation result from offchain.
     * @param signature    The signature that from a authorized computer party.
     */
    function fulfillJobForSimple(uint256 requestId, bytes calldata result, bytes memory signature) external {
        _validateResult(result, signature);

        if (requestToJob[requestId].jobType != JobType.SIMPLE) {
            revert InvalidJobType();
        }

        // o the decode work and callback
        bool success;
        emit JobForSimpleFulfilled(requestId, success);
    }

    /**
     * @notice fulfill a complex job.
     *
     * @param requestId    The request identifier.
     * @param result       The computation result from offchain.
     * @param signature    The signature that from a authorized computer party.
     */
    function fulfillJobForComplex(uint256 requestId, bytes calldata result, bytes memory signature) external {
        _validateResult(result, signature);

        if (requestToJob[requestId].jobType != JobType.COMPLEX) {
            revert InvalidJobType();
        }
        //do the decode work and callback
        bool success;
        emit JobForComplexFulfilled(requestId, success);
    }

    function updateOffchainComputer(address computer, bool status) external onlyOwner {
        authorizedComputer[computer] = status;
        emit ComputerAuthorized(computer, status);
    }

    //todo Function to verify zk-SNARK proof (placeholder)
    function _verifyZKProof(uint256 requestId, bytes calldata result, bytes memory signatur, bytes calldata proof)
        internal
    {
        // Implement zk-SNARK verification logic here
        // This is a placeholder and would require integration with a zk-SNARK library
    }

    //todo Randomness validate，result include the proof and request commitment. proof include seed,random number and requestId.
    function _getRandomnessFromProof(Proof calldata proof, RequestCommitment memory rc)
        private
        view
        returns (bytes32 keyHash, uint256 requestId, uint256 randomness)
    {
        // randomness = VRF._randomValueFromVRFProof(proof, actualSeed); // Reverts on failure
        // return (keyHash, requestId, randomness);
    }

    function _validateResult(bytes calldata data, bytes memory signature) internal view {
        address signer = keccak256(data).toEthSignedMessageHash().recover(signature);

        if (!authorizedComputer[signer]) {
            revert UnauthorizedSource();
        }
    }

    function _computeRequestId(address sender, uint256 subId, uint256 nonce) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(sender, subId, nonce)));
    }
}
