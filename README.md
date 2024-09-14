# Simple Oracle
# Overview
This project has implemented a basic example of on-chain and off-chain interaction through hardhat and foundry, mainly including the following functions:
1. UUPS upgradable contract
2. Provide on-chain subscription service management function, allowing users to manage subscriptions
3. Provide consumer management services that allow subscribers to manage consumers
4. Example of a consumer contract requesting a random number
5. Support customizing different types of work and executing different requests according to different types
6. Off-chain result verification. Only results returned by authorized off-chain computing parties are accepted.
# Interaction Flow
1. Users create subscriptions through createSubscriptition and get a unique subscription ID currentSubId
2. Users add consumers through addConsumer , which is a contract that requires the Oracle service
3. Request the Consumer contract, internally call the Coordinator contract to issue a task request, and include the task type (in this case, the type bit requests a random number). Throw the event RequestSent
4. Coordinator receives a request from a consumer, creates a Job, returns a requestId, and throws a JobRequest event
5. After listening to the JobRequest event, the corresponding work is performed according to the type of task. In this example, a random number is generated
6. After the off-chain work is completed, the corresponding method to complete the task in the Coordinator contract is called according to the task type. In this case, fulfillJobForRandom is called, and the signature of the off-chain computing party is included to verify that it is the result returned by the authorized off-chain computing party.
7. The Coordinator calls back to the consumer contract.
8. The consumer contract can only be called through the Coordinator contract to obtain the final result and complete this off-chain request.

# Execution
```shell
npm i
hh compile
hh test test/Coordinator.js 
```
