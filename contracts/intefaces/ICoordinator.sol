// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ICoordinator {
    /**
     * @notice A enum defining Job type
     *
     */
    enum JobType {
        SIMPLE,
        COMPLEX,
        RANDOM
    }

    /**
     * @notice A struct defining Subscription
     *
     * @param active                   The subscripiton status.
     * @param subscriber               The subscriber that create the subscripiton.
     * @param balance                  The balance of the subscripiton.
     * @param consumers                Consumers in the subscripiton.
     *
     */
    struct Subscription {
        bool active;
        address subscriber;
        uint256 balance;
        address[] consumers;
    }

    /**
     * @notice A struct defining Job.
     *
     * @param requestId                Request identifier, which is uniquely determined by the
     *                                    subscriber and consumer.
     * @param sender                   Sender who request the job.
     * @param jobType                  Enum JobType
     *
     */
    struct Job {
        uint256 requestId;
        address sender;
        JobType jobType;
    }

    struct RequestCommitment {
        uint64 blockNum;
        uint64 subId;
        uint32 callbackGasLimit;
        uint32 numWords;
        address sender;
    }

    event JobCreated(uint256 jobId, address requester, bytes data);
    event JobCompleted(uint256 jobId, bytes result);
    event SubscriptionCreated(uint256 subId, address subscriber);
    event SubscriptionCancelled(uint256 subId);
    event SubscriptionConsumerAdded(uint256 subId, address consumer);
    event SubscriptionConsumerRemoved(uint256 subId, address consumer);
    event JobRequest(uint256 subId, uint256 requestId, address sender, JobType jobType);
    event JobForRandomFulfilled(uint256 requestId, bool sucess);
    event JobForSimpleFulfilled(uint256 requestId, bool sucess);
    event JobForComplexFulfilled(uint256 requestId, bool sucess);
    event ComputerAuthorized(address computer, bool status);

    error ExistSubscription();
    error NoActiveSubscription();
    error InvalidSubscriber();
    error TooManyConsumers();
    error ExistedConsumer();
    error InvalidConsumer();
    error InvalidSubscription();
    error UnauthorizedSource();
    error InvalidJobType();
    error JobFailed();

    function requestJob(uint256 subId, JobType jobType) external returns (uint256);
    /*
     * subscription
     */
    function createSubscription() external;
    function cancelSubscription(uint256 subId) external;
    function fundSubscription(uint256 subId) external payable;
    /*
     * consumer
     */
    function addConsumer(uint256 subId, address consumer) external;
    function removeConsumer(uint64 subId, address consumer) external;

    /*
     * fufill job
     */
    function fulfillJobForRandom(uint256 requestId, bytes calldata result, bytes calldata signature);
    function fulfillJobForSimple(uint256 requestId, bytes calldata result, bytes memory signature) external;
    function fulfillJobForComplex(uint256 requestId, bytes calldata result, bytes memory signature) external;

    /*
     * config
     */
    function updateOffchainComputer(address computer, bool status) external;
}
