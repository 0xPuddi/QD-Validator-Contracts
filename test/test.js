require("hardhat-gas-reporter");

const { getSelectors, FacetCutAction, removeSelectors, findAddressPositionInFacets } = require('../scripts/diamond.js');

const { deployDiamond } = require('../scripts/deploy.js');

const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

const { deploySimpleContract } = require('../scripts/deployContract.js');

const { assert, expect } = require('chai');
const { ethers, network, hre } = require("hardhat");
const { TASK_COMPILE_SOLIDITY_GET_ARTIFACT_FROM_COMPILATION_OUTPUT } = require("hardhat/builtin-tasks/task-names.js");

function parseEther(number) {
    return ethers.utils.parseEther('' + number);
}

describe('DiamondTestQD', async function () {
    let diamondAddress;
    let diamondCutFacet;
    let diamondLoupeFacet;
    let ownershipFacet;

    let ERC1155Facet;
    let ERC1155FacetOwner;
    let ERC1155FacetUser1;

    let AvalancheValidatorFacet;
    let AvalancheValidatorFacetOwner;
    let AvalancheValidatorFacetUser1;
    let AvalancheValidatorFacetUser2;
    let AvalancheValidatorFacetUser3;
    let AvalancheValidatorFacetUser5;

    let AvalancheValidatorDepositFacet;
    let AvalancheValidatorDepositFacetOwner;
    let AvalancheValidatorDepositFacetUser1;
    let AvalancheValidatorDepositFacetUser2;

    let AvalancheValidatorSettersAndGettersFacet;
    let AvalancheValidatorSettersAndGettersFacetOwner;

    let AvalancheValidatorHealthAndUpgradesFacet;
    let AvalancheValidatorHealthAndUpgradesFacetOwner;
    let AvalancheValidatorHealthAndUpgradesFacetUser1;
    let AvalancheValidatorHealthAndUpgradesFacetUser2;
    let AvalancheValidatorHealthAndUpgradesFacetUser3;
    let AvalancheValidatorHealthAndUpgradesFacetUser5;

    let AvalancheValidatorTokenFacet;
    let AvalancheValidatorTokenFacetOwner;
    let AvalancheValidatorTokenFacetUser1;
    let AvalancheValidatorTokenFacetUser2;

    let facets;
    let users;

    let tx;
    let recepit;

    let ERC20;
    let ERC20User1;
    let ERC721;
    let ERC721User1;

    before(async function () {
        diamondAddress = await deployDiamond();

        diamondCutFacet = await ethers.getContractAt('DiamondCutFacet', diamondAddress);
        diamondLoupeFacet = await ethers.getContractAt('DiamondLoupeFacet', diamondAddress);
        ownershipFacet = await ethers.getContractAt('OwnershipFacet', diamondAddress);

        ERC1155Facet = await ethers.getContractAt('ERC1155Facet', diamondAddress);
        AvalancheValidatorFacet = await ethers.getContractAt('AvalancheValidatorFacet', diamondAddress);
        AvalancheValidatorDepositFacet = await ethers.getContractAt('AvalancheValidatorDepositFacet', diamondAddress);
        AvalancheValidatorSettersAndGettersFacet = await ethers.getContractAt('AvalancheValidatorSettersAndGettersFacet', diamondAddress);
        AvalancheValidatorHealthAndUpgradesFacet = await ethers.getContractAt('AvalancheValidatorHealthAndUpgradesFacet', diamondAddress);
        AvalancheValidatorTokenFacet = await ethers.getContractAt('AvalancheValidatorTokenFacet', diamondAddress);

        facets = await diamondLoupeFacet.facetAddresses();

        users = await ethers.getSigners();

        ERC1155FacetUser1 = ERC1155Facet.connect(users[1]);
        ERC1155FacetOwner = ERC1155Facet.connect(users[0]);

        AvalancheValidatorFacetOwner = AvalancheValidatorFacet.connect(users[0]);
        AvalancheValidatorFacetUser1 = AvalancheValidatorFacet.connect(users[1]);
        AvalancheValidatorFacetUser2 = AvalancheValidatorFacet.connect(users[2]);
        AvalancheValidatorFacetUser3 = AvalancheValidatorFacet.connect(users[3]);
        AvalancheValidatorFacetUser5 = AvalancheValidatorFacet.connect(users[5]);

        AvalancheValidatorSettersAndGettersFacetOwner = AvalancheValidatorSettersAndGettersFacet.connect(users[0]);

        AvalancheValidatorDepositFacetOwner = AvalancheValidatorDepositFacet.connect(users[0]);
        AvalancheValidatorDepositFacetUser1 = AvalancheValidatorDepositFacet.connect(users[1]);
        AvalancheValidatorDepositFacetUser2 = AvalancheValidatorDepositFacet.connect(users[2]);

        AvalancheValidatorHealthAndUpgradesFacetOwner = AvalancheValidatorHealthAndUpgradesFacet.connect(users[0]);
        AvalancheValidatorHealthAndUpgradesFacetUser1 = AvalancheValidatorHealthAndUpgradesFacet.connect(users[1]);
        AvalancheValidatorHealthAndUpgradesFacetUser2 = AvalancheValidatorHealthAndUpgradesFacet.connect(users[2]);
        AvalancheValidatorHealthAndUpgradesFacetUser3 = AvalancheValidatorHealthAndUpgradesFacet.connect(users[3]);
        AvalancheValidatorHealthAndUpgradesFacetUser5 = AvalancheValidatorHealthAndUpgradesFacet.connect(users[5]);

        AvalancheValidatorTokenFacetOwner = AvalancheValidatorTokenFacet.connect(users[0]);
        AvalancheValidatorTokenFacetUser1 = AvalancheValidatorTokenFacet.connect(users[1]);
        AvalancheValidatorTokenFacetUser2 = AvalancheValidatorTokenFacet.connect(users[2]);

        addressERC20 = await deploySimpleContract('ERC20', 'token20', 'T20');
        ERC20 = await ethers.getContractAt('ERC20', addressERC20);
        ERC20User1 = ERC20.connect(users[1]);
        addressERC721 = await deploySimpleContract('ERC721', 'token721', 'T721');
        ERC721 = await ethers.getContractAt('ERC721', addressERC721);
        ERC721User1 = ERC721.connect(users[1]);
    });

    it("Mint, incentives", async () => {
        console.log('----------------------');
        // Set and get cooling period
        tx = await AvalancheValidatorSettersAndGettersFacetOwner.setRewardsDurationManual(1_800);
        tx.wait(1);
        tx = await AvalancheValidatorSettersAndGettersFacetOwner.setCoolingPeriodManual(1_800);
        recepit = await tx.wait(1)
        let _coolingPeriodStartInSeconds = ethers.utils.defaultAbiCoder.decode(['uint256', 'uint256'], recepit.logs[0].data)[1].toString();
        assert.equal((await AvalancheValidatorSettersAndGettersFacet.getCoolingPeriodAndCoolingPeriodStart()).toString(), '1800,' + _coolingPeriodStartInSeconds, '1');

        // Wait rewards
        await network.provider.send("evm_increaseTime", [601]);
        await network.provider.send("evm_mine");

        tx = await AvalancheValidatorDepositFacetOwner.mintAvalancheValidatorShareAVAX(1000, "0x", { value: ethers.utils.parseUnits('100', "ether").toString() });
        recepit = await tx.wait(1);

        // Mint
        tx = await AvalancheValidatorDepositFacetUser1.mintAvalancheValidatorShareAVAX(10000, "0x", { value: ethers.utils.parseUnits('1000', "ether").toString() });
        tx.wait(1);

        // Try add capital
        await expect(AvalancheValidatorDepositFacetOwner.depositRewards(0, [0, 1, 2, 3, 4])).to.be.revertedWith("reward rate = 0");

        // Get cooling period
        assert.equal
            ((
                await AvalancheValidatorSettersAndGettersFacet.getIsUnderCoolingPeriod(users[0].address, 0)).toString(),
                'true,' + (parseInt((
                    await AvalancheValidatorSettersAndGettersFacet.getOwnerHealth(users[0].address, 0)).toString()) -
                    parseInt((await AvalancheValidatorSettersAndGettersFacet.getTime()).toString())), 'Cooling period'
            );

        // Burn shares
        tx = await AvalancheValidatorDepositFacetOwner.burnShares([0], [10]);
        tx.wait(1);

        // Add incentives
        tx = await AvalancheValidatorDepositFacet.depositIncentives(5000, 100, { value: ethers.utils.parseUnits('50', "ether").toString() });
        tx.wait(1);

        // Mint with incentives
        tx = await AvalancheValidatorDepositFacetUser2.mintAvalancheValidatorShareAVAX(100, "0x", { value: ethers.utils.parseUnits('50', "ether").toString() });
        tx.wait(1);

        // Close incentives
        tx = await AvalancheValidatorFacet.withdrawIncentives();
        tx.wait(1);

        // Mint without incentives
        tx = await AvalancheValidatorDepositFacetUser2.mintAvalancheValidatorShareAVAX(10, "0x", { value: ethers.utils.parseUnits('1', "ether").toString() });
        tx.wait(1);

        // Upgarde shares
        tx = await AvalancheValidatorHealthAndUpgradesFacetUser1.upgradeAvalancheValidatorLevel([0, 1, 2], [100, 10, 1]); // Get share level 3
        tx.wait(1);

        // Check balance
        assert.equal((await ERC1155Facet.balanceOfBatch
            (
                [users[1].address, users[1].address, users[1].address, users[1].address], [0, 1, 2, 3]
            )).toString(), '9000,0,0,1');

        // Add referral
        tx = await AvalancheValidatorHealthAndUpgradesFacetOwner.manageReferralAddress(users[1].address);
        tx.wait(1);

        // Wait cooling period finsh 1202 from 1st 1800 coolingPeriod
        await network.provider.send("evm_increaseTime", [601]);
        await network.provider.send("evm_mine");

        // Deposit Rewards
        tx = await AvalancheValidatorDepositFacetOwner.depositRewards(0, [0, 1, 2, 3, 4], { value: ethers.utils.parseEther('1.0') });
        tx.wait(1);

        // Wait seconds between actions to add rewards
        await network.provider.send("evm_increaseTime", [1]);
        await network.provider.send("evm_mine");

        // // Check rewards per token ID
        // // assert.equal((await AvalancheValidatorSettersAndGettersFacet.getRewardPerTokenID([0,1,2,3,4])).toString(), '67567567567567425742574257425,0,0,67567567567567000000000000000000,0');
        assert.equal((await AvalancheValidatorSettersAndGettersFacet.getCurrentActiveSupplies()).toString(), '10100,0,0,1,0');

        // // Wait cooling period finsh 1804 from 1st 1800 coolingPeriod, 4 in 2nd 1800 cooling period
        await network.provider.send("evm_increaseTime", [601]);
        await network.provider.send("evm_mine");

        /**
         * Complete all actions that have update rewards
         * 
         * burnShares
         * mintAvalancheValidatorShareAVAX
         * refreshAvalancheValidatorSharesHealth
         * upgradeAvalancheValidatorLevel
         * manageInactiveValidatorShares
         * depositRefunds
         * redeemRefund
         * manageUnclaimedRefunds
         */
        // burn shares
        tx = await AvalancheValidatorDepositFacetOwner.burnShares([0], [100]);
        tx.wait(1);
        tx = await AvalancheValidatorDepositFacetUser1.burnShares([0], [1000]);
        tx.wait(1);

        assert.equal((await ERC1155Facet.balanceOfBatch([users[0].address, users[0].address, users[0].address, users[0].address, users[0].address], [0, 1, 2, 3, 4])).toString(), '890,0,0,0,0');
        assert.equal((await ERC1155Facet.balanceOfBatch([users[1].address, users[1].address, users[1].address, users[1].address, users[1].address], [0, 1, 2, 3, 4])).toString(), '8000,0,0,1,0');
        assert.equal((await ERC1155Facet.balanceOfBatch([users[2].address, users[2].address, users[2].address, users[2].address, users[2].address], [0, 1, 2, 3, 4])).toString(), '110,0,0,0,0');

        // Mint
        tx = await AvalancheValidatorDepositFacetOwner.mintAvalancheValidatorShareAVAX(1000, "0x", { value: ethers.utils.parseUnits('100', "ether").toString() });
        tx.wait(1);

        // Refresh health
        tx = await AvalancheValidatorHealthAndUpgradesFacetUser1.refreshAvalancheValidatorSharesHealth([0, 3]);
        tx.wait(1);

        // Upgrade levels
        assert.equal((await ERC1155Facet.balanceOfBatch([users[0].address, users[0].address, users[0].address, users[0].address, users[0].address], [0, 1, 2, 3, 4])).toString(), '1890,0,0,0,0');
        tx = await ERC1155FacetOwner.safeTransferFrom(users[0].address, users[5].address, 0, 880, "0x");
        tx.wait(1);
        tx = await AvalancheValidatorHealthAndUpgradesFacetOwner.upgradeAvalancheValidatorLevel([0, 1, 2], [100, 10, 1]); //  Get shares level 3
        tx.wait(1);

        // Merkletree
        let values = [
            [users[1].address, 100, 0],
            [users[0].address, 10, 0]
        ]
        // let leaves = values.map(x => keccak256(x))
        let leavesEncoded = values.map(x => keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256"], [x[0], x[1], x[2]])))
        const tree = new MerkleTree(leavesEncoded, keccak256, { sortPairs: true })
        const buf2hex = x => '0x' + x.toString('hex')
        let mrkletree = buf2hex(tree.getRoot())
        // Add refunds avD
        let depositRefunds = await AvalancheValidatorDepositFacetOwner.depositRefunds([110, 0, 0, 0, 0], [0, 1, 2, 3, 4], mrkletree, 50, { value: ethers.utils.parseUnits('9.35', 'ether') }) // 85% refunds perc.
        await depositRefunds.wait(1)

        // Redeem refunds
        let leaf0 = keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256"], [users[1].address, 100, 0]))
        let proof0 = tree.getProof(leaf0).map(x => buf2hex(x.data))
        let redeemtxn = await AvalancheValidatorFacetUser1.redeemRefund(100, 0, proof0) // account 1 redeem
        await redeemtxn.wait(1)

        // Expire refund
        await network.provider.send("evm_increaseTime", [51]);
        await network.provider.send("evm_mine");

        // Manage refunds
        let leaf1 = keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256"], [users[0].address, 10, 0]))
        let proof1 = tree.getProof(leaf1).map(x => buf2hex(x.data))
        tx = await AvalancheValidatorFacetUser1.manageUnclaimedRefunds(users[0].address, 10, 0, proof1) // manage account 0
        tx.wait(1);

        // Transfer between owner from owned to not owned - overflow occours after this block
        tx = await ERC1155FacetUser1.safeTransferFrom(users[1].address, users[2].address, 0, 10, '0x');
        tx.wait(1);
        tx = await ERC1155FacetUser1.safeTransferFrom(users[1].address, users[3].address, 0, 10, '0x');
        tx.wait(1);

        // Wait entire period from 4 2nd to 4 3rd coolingPeriod
        await network.provider.send("evm_increaseTime", [1_850]);
        await network.provider.send("evm_mine");

        // Manage inactive shares
        tx = await AvalancheValidatorFacetUser3.manageInactiveValidatorShares(users[2].address, 0);
        tx.wait(1);

        /**
         * Check rewards collected are worth 1 ether and collect them
         * collectRewards
         */
        // console.log("Stats:")
        // console.log((await AvalancheValidatorSettersAndGettersFacet.getIdRewardsAndQDFee()).toString()); 
        // console.log((await AvalancheValidatorSettersAndGettersFacet.getRewardPerTokenID([0,1,2,3,4])).toString());
        // console.log((await AvalancheValidatorSettersAndGettersFacet.getCurrentActiveSupplies()).toString());
        // console.log((await AvalancheValidatorSettersAndGettersFacet.getCurrentSupplies()).toString());

        // console.log("Balances:")
        // console.log((await ERC1155Facet.balanceOfBatch([users[0].address,users[0].address,users[0].address,users[0].address,users[0].address], [0,1,2,3,4])).toString());
        // console.log((await ERC1155Facet.balanceOfBatch([users[1].address,users[1].address,users[1].address,users[1].address,users[1].address], [0,1,2,3,4])).toString());
        // console.log((await ERC1155Facet.balanceOfBatch([users[2].address,users[2].address,users[2].address,users[2].address,users[2].address], [0,1,2,3,4])).toString());
        // console.log((await ERC1155Facet.balanceOfBatch([users[3].address,users[3].address,users[3].address,users[3].address,users[3].address], [0,1,2,3,4])).toString());
        // console.log((await ERC1155Facet.balanceOfBatch([users[5].address,users[5].address,users[5].address,users[5].address,users[5].address], [0,1,2,3,4])).toString());

        // console.log("Rewards:")
        // console.log((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[0].address)).toString()); 
        // console.log((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[1].address)).toString()); 
        // console.log((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[2].address)).toString()); 
        // console.log((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[3].address)).toString()); 
        // console.log((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[5].address)).toString()); 
        // console.log("---------------------------")

        // Refresh health
        tx = await AvalancheValidatorHealthAndUpgradesFacetOwner.refreshAvalancheValidatorSharesHealth([3]);
        tx.wait(1);
        tx = await AvalancheValidatorHealthAndUpgradesFacetUser1.refreshAvalancheValidatorSharesHealth([0, 3]);
        tx.wait(1);
        expect(AvalancheValidatorHealthAndUpgradesFacetUser2.refreshAvalancheValidatorSharesHealth([0])).to.be.revertedWith('No shares');
        tx = await AvalancheValidatorHealthAndUpgradesFacetUser3.refreshAvalancheValidatorSharesHealth([0]);
        tx.wait(1);
        tx = await AvalancheValidatorHealthAndUpgradesFacetUser5.refreshAvalancheValidatorSharesHealth([0]);
        tx.wait(1);

        // Collect rewards
        tx = await AvalancheValidatorFacetOwner.collectRewards([0, 3]);
        tx.wait(1);
        expect(AvalancheValidatorFacetUser2.collectRewards([0])).to.be.revertedWith('No shares');
        tx = await AvalancheValidatorFacetUser3.collectRewards([0]);
        tx.wait(1);
        tx = await AvalancheValidatorFacetUser1.collectRewards([0, 3]);
        tx.wait(1);
        tx = await AvalancheValidatorFacetUser5.collectRewards([0]);
        tx.wait(1);

        assert.equal((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[0].address)).toString(), '0,0,0,0,0');
        assert.equal((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[1].address)).toString(), '0,0,0,0,0');
        assert.equal((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[2].address)).toString(), '0,0,0,0,0');
        assert.equal((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[3].address)).toString(), '0,0,0,0,0');
        assert.equal((await AvalancheValidatorSettersAndGettersFacet.getAllOwnerRewards(users[5].address)).toString(), '0,0,0,0,0');

        // Close Refunds
        tx = await AvalancheValidatorHealthAndUpgradesFacetOwner.withdrawRefunds();
        tx.wait(1);

        // Collect avax to stake
        tx = await AvalancheValidatorFacetOwner.withdrawQuarryDrawRewardFee();
        tx.wait(1);
        tx = await AvalancheValidatorFacetOwner.withdrawAvaxToStake();
        tx.wait(1);

        // Check diamond balance
        console.log((await AvalancheValidatorSettersAndGettersFacet.getIdRewardsAndQDFee()).toString()) // 
        console.log((await ethers.provider.getBalance(diamondAddress)).toString()); // 0.000045495495496404 ok
        console.log((await AvalancheValidatorSettersAndGettersFacet.getRefundsStats()).toString()); // 
        console.log((await AvalancheValidatorSettersAndGettersFacet.getIncentivesStats()).toString()); // 
        console.log((await AvalancheValidatorSettersAndGettersFacet.getAvaxToStake()).toString()); // 

        expect(ERC1155FacetUser1.safeTransferFrom(users[1].address, diamondAddress, 0, 10, '0x')).to.be.revertedWith('ERC1155: ERC1155Receiver rejected tokens');
    });
});