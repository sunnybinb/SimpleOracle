const { expect } = require("chai")
const { ethers } = require("hardhat")
// const {arrayify} = require("ethers");

//get random number
function getRandomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

describe("Coordinator", () => {
    let Coordinator;
    let RandomConsumer;
    beforeEach(async () => {
        ;[owner, user1, user2, signer] = await ethers.getSigners()

        //deploy Coordinator
        Coordinator = await ethers.getContractFactory('Coordinator');
        Coordinator = await upgrades.deployProxy(Coordinator, []);
        //console.log(Coordinator.target)
        //deploy Consumer
        RandomConsumer = await ethers.getContractFactory("RandomConsumer")
        RandomConsumer = await RandomConsumer.deploy(Coordinator.target)

    })

    describe("test init", () => {
        it("init should success", async function () {
            expect(await Coordinator.owner()).to.be.equal(owner.address)
        })
    })
    describe("test request job", () => {
        describe("test request job sucessfully", () => {
            it("request random number", async function () {
                //1.createSubscription. 
                await Coordinator.createSubscription();
                let subId = 0;
                let subscription = await Coordinator.subIdToSubscription(subId);
                expect(subscription[1]).to.be.equal(owner.address)

                //2. add consumer 
                await Coordinator.addConsumer(subId, RandomConsumer.target);
                expect(await Coordinator.consumerNonce(RandomConsumer.target, subId)).to.be.equal(1)


                //3. requestJob from consumer 
                tx = await RandomConsumer.requestRandomNumber();
                let requestId = await RandomConsumer.requestId();
                expect(await Coordinator.consumerNonce(RandomConsumer.target, subId)).to.be.equal(2)

                //4. fufill job offchain, assuming has listened the JobRequest event

                //4.1 get random number
                let randomNumber = getRandomInt(1, 10000000)
                const abiCoder = new ethers.AbiCoder;
                const encodedData = abiCoder.encode(["uint256"], [randomNumber]);
                //4.2 sig              
                const messageHash = ethers.keccak256(encodedData);
                const signature = await signer.signMessage(ethers.getBytes(messageHash))

                //4.3 authorized computer
                await Coordinator.updateOffchainComputer(signer.address, true);
                //4.4 fulfill 
                await Coordinator.fulfillJobForRandom(requestId, encodedData, signature)
    
                expect(await RandomConsumer.randomWord()).to.be.equal(randomNumber)

            })
        })
        describe("test request job failed", () => {
            it("add consumer by not owner failed", async function () {
            })
        })
    })

})
