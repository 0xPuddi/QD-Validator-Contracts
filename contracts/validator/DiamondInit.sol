// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import { ValidatorStorage } from "./ValidatorStorage.sol";

import { IDiamondCut } from "../shared/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "../shared/interfaces/IDiamondLoupe.sol";
import { IERC173 } from "../shared/interfaces/IERC173.sol";
import { IERC165 } from "../shared/interfaces/IERC165.sol";
import { IERC1155 } from "../shared/interfaces/IERC1155.sol";
import { IERC1155MetadataURI } from "../shared/interfaces/IERC1155MetadataURI.sol";
import { IERC1155Receiver } from "../shared/interfaces/IERC1155Receiver.sol";
import { IERC2981 } from "../shared/interfaces/IERC2981.sol";

import { LibDiamond } from "../shared/libraries/LibDiamond.sol";
import { LibReentrancyGuardStorage } from "../shared/libraries/LibReentrancyGuardStorage.sol";

// It is expected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

contract DiamondInit { // add _duration (2weeks - 30min) add _rewardCoolingPeriod(30 min)
    // You can add parameters to this function in order to pass in 
    // data to set your own state variables
    function init( string memory baseURI, uint256[5] memory tokenId, string[5] memory tokenURI, address owner, uint96 royialtyFeeInBPS) external {
        LibDiamond.enforceIsContractOwner();

        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        ds.supportedInterfaces[type(IERC1155).interfaceId] = true;
        ds.supportedInterfaces[type(IERC1155MetadataURI).interfaceId] = true;
        ds.supportedInterfaces[type(IERC1155Receiver).interfaceId] = true;
        ds.supportedInterfaces[type(IERC2981).interfaceId] = true;

        // add your own state variables 
        // EIP-2535 specifies that the `diamondCut` function takes two optional 
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface

        // LibReentrancyGuard
        LibReentrancyGuardStorage.Layout storage lrgs = LibReentrancyGuardStorage.layout();
        lrgs.status = 1;

        // ERC1155Facet and AvalancheValidatorFacet
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        // ERC1155Facet constructor
        vs.AV._baseURI = baseURI;
        for (uint256 i = 0; i < tokenId.length; ) {
            vs.AV._tokenURIs[tokenId[i]] = tokenURI[i];
            unchecked {
                ++i;
            }
        }
        vs.AV._defaultRoyaltyInfo.receiver = owner;
        vs.AV._defaultRoyaltyInfo.royaltyFraction = royialtyFeeInBPS;
        // FirstAvalancheValidatorFacet constructor
        // Assign token IDs
        vs.AV.AVALANCHE_VALIDATOR_LVL1 = 0;
        vs.AV.AVALANCHE_VALIDATOR_LVL2 = 1;
        vs.AV.AVALANCHE_VALIDATOR_LVL3 = 2;
        vs.AV.AVALANCHE_VALIDATOR_LVL4 = 3;
        vs.AV.AVALANCHE_VALIDATOR_LVL5 = 4;
        // Assign names and simbols
        vs.AV._name = "QuarryDraw - Avalanche Validator 1";
        vs.AV._symbol = "qdAV1";
        // Assign max supply
        vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[0] = 30000000; // 25'710'000 to make lvl2 + 4'290'000 of max level1 supply
        vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[1] = 2571000; // 2'076'000 to make lvl3 + 495'000 of max level2 supply
        vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[2] = 207600; // 150'300 to make lvl4 + 57'300 of max level3 supply
        vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[3] = 15030; // 8'280 to make lvl5 + 6'750 of max level4 supply
        vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[4] = 828;
        // Assign share cost
        vs.AV.shareCost = 100000000000000000; // 0.1 ether 1*10^17 - in wei
        // vs.AV.shareCost = 1_000_000_000_00; // 0.0000001 ether testnet
        // Assign refundsPercentage
        vs.AV.refundsPercentage = 8500;
        vs.AV.managerRefundsPercentage = 1500;
        // Assign QuarryDraw fee
        vs.AV.QDValidatorFee = 1000; // BPS
        vs.AV.QDLiquidStakingFee = 2500; // BPS
        vs.AV.percentageProportion = 10000; // Standard no float involved for two decimal: BPS
        // Assign acctivity period
        // vs.AV.activityPeriod = 31 days;
        vs.AV.activityPeriod = 30*60; // testnet 4h
        // vs.AV.coolingPeriod = 2 weeks;
        vs.AV.coolingPeriod = 30*60; // testnet
        vs.AV.coolingPeriodStart = block.timestamp;
        // Assign Duration and reward cooling period
        // vs.AV.duration = 2 weeks - 30 * 60;
        vs.AV.duration = 30*60 - 10 * 60; // testnet
        // vs.AV.rewardCoolingPeriod = 30 * 60;
        vs.AV.rewardCoolingPeriod = 10 * 60; // testnet
        // Add referral percentages
        vs.AV.referralRewards[0] = 0;
        vs.AV.referralRewards[1] = 100;
        vs.AV.referralRewards[2] = 200;
        vs.AV.referralRewards[3] = 200;
        vs.AV.referralRewards[4] = 300;
        vs.AV.referralRewards[5] = 300;
        vs.AV.referralRewards[6] = 300;
        vs.AV.referralRewards[7] = 400;
        vs.AV.referralRewards[8] = 400;
        vs.AV.referralRewards[9] = 400;
        vs.AV.referralRewards[10] = 400;
        vs.AV.referralRewards[11] = 500;
        vs.AV.referralRewards[12] = 500;
        vs.AV.referralRewards[13] = 500;
        vs.AV.referralRewards[14] = 500;
        vs.AV.referralRewards[15] = 500;
    }
}