// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";

import { IAvalancheValidatorSettersAndGettersFacet } from "../interfaces/IAvalancheValidatorSettersAndGettersFacet.sol";

import { LibDiamond } from "../../shared/libraries/LibDiamond.sol";
import { LibAvalancheValidatorFacet } from "../libraries/LibAvalancheValidatorFacet.sol";
import { LibAvalancheValidatorDepositFacet } from "../libraries/LibAvalancheValidatorDepositFacet.sol";
import { LibERC1155Facet } from "../libraries/LibERC1155Facet.sol";

contract AvalancheValidatorSettersAndGettersFacet is IAvalancheValidatorSettersAndGettersFacet {
    /// Cleaner ///
    /// @dev Clean redeemer mapping
    function cleanRedeemedMappingExternal(uint256[] memory _ids) external returns(bool) {
        return LibAvalancheValidatorFacet.cleanRedeemedMapping(_ids);
    }
    
    /// Setters ///

    /// @dev Set activityPeriod
    function setActivityPeriodManual(uint256 _timeInSecond) external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        vs.AV.activityPeriod = _timeInSecond;
        emit settedActivityPeriod(_timeInSecond, block.timestamp);
        return true;
    }

    /// @dev Set shareCost - dangerous, should we mantain it?
    function setShareCostManual(uint256 _costInWei) external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        vs.AV.shareCost = _costInWei;
        emit settedShareCost(_costInWei, block.timestamp);
        return true;
    }

    /// @dev Set _defaultRoialtyInfo
    function setDefaultRoyaltyManual(address _receiver, uint96 feeNumeratorInBPS) external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        require(_receiver != address(0), "ERC2981: invalid receiver");
        require(feeNumeratorInBPS <= vs.AV.percentageProportion, "ERC2981: royalty fee will exceed salePrice");
        LibERC1155Facet._setDefaultRoyalty(_receiver, feeNumeratorInBPS);
        emit settedDefaultRoyalty(_receiver, feeNumeratorInBPS);
        return true;
    }

    /// @dev Set coolingPeriod
    function setCoolingPeriodManual(uint256 _coolingPeriodInSecond) external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        vs.AV.coolingPeriod = _coolingPeriodInSecond;
        vs.AV.coolingPeriodStart = block.timestamp;
        emit settedCoolingPeriod(_coolingPeriodInSecond, block.timestamp);
        return true;
    }

    /// @dev Set a new refunds percentage
    function setRefundsAndRefundsManagerPercentageManual(uint256 _newRefundsPercentageInBPS, uint256 _newManagerRefundsPercentageInBPS) external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        require(_newRefundsPercentageInBPS + _newManagerRefundsPercentageInBPS == vs.AV.percentageProportion, "Not complessively 100% or more");
        vs.AV.refundsPercentage = _newRefundsPercentageInBPS;
        vs.AV.managerRefundsPercentage = _newManagerRefundsPercentageInBPS;
        emit settedRefundsAndRefundsManagerPercentage(_newRefundsPercentageInBPS, _newManagerRefundsPercentageInBPS, block.timestamp);
        return true;
    }

    /// @dev Set rewards duration manually
    function setRewardsDurationManual(uint256 _durationInSecond) external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        LibAvalancheValidatorFacet.setRewardsDuration(_durationInSecond);
        return true;
    }

    /// @dev Set if the next validator has been completed + renounce ownership?
    function setNextValidatorCompletedManual(address _receiver) external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        vs.AV.isNextValidatorCompleted = true;
        require(_receiver != address(0), "ERC2981: invalid receiver");
        require(100 <= vs.AV.percentageProportion, "ERC2981: royalty fee will exceed salePrice");
        LibERC1155Facet._setDefaultRoyalty(_receiver, 100);
        emit settedDefaultRoyalty(_receiver, 100);
        emit settedNextValidatorIsCompleted(_receiver, block.timestamp);
        return true;
    }

    /// Getters ///

    /// @dev Total current cooling amount of tokens in with a given id.
    function getCurrentCoolingSupply(uint256 _id) public view virtual returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[_id];
    }

    /// @dev Get if is under cooling period and remaining time
    function getIsUnderCoolingPeriod(address _owner, uint256 _id) public view returns(bool, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        bool _isUnderCoolingPeriod = LibAvalancheValidatorFacet.isUnderCoolingPeriod(_owner, _id);
        uint256 _ownerCoolingPeriod;
        if (_isUnderCoolingPeriod) {
            _ownerCoolingPeriod = vs.AV.health[_id][_owner] - block.timestamp;
        }
        return (_isUnderCoolingPeriod, _ownerCoolingPeriod);
    }

    /// @dev Get current active supplies
    function getTotalCurrentSupplyPondered() public view returns(uint256 AV_ACTIVE_PONDERED_SUPPLIES) {
        /// Get variables
        AV_ACTIVE_PONDERED_SUPPLIES = LibAvalancheValidatorDepositFacet.getTotalCurrentSupplyPondered();
    }

    /// @dev Get current active supplies
    function getCurrentActiveSupplies() public view returns(uint256[5] memory AV_ACTIVE_SUPPLIES) {
        /// Get variables
        AV_ACTIVE_SUPPLIES = LibAvalancheValidatorDepositFacet.getCurrentActiveSupplies();
    }

    /// @dev Get current active supplies
    function getCurrentSupplies() public view returns(uint256[5] memory AV_CURRENT_SUPPLIES) {
        /// Get variables
        AV_CURRENT_SUPPLIES = LibAvalancheValidatorDepositFacet.getCurrentSupplies();
    }

    function getOwnerRewards(address owner, uint256 id) public view returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.rewards[id][owner];
    }

    /// @dev Get all owner rewards
    function getAllOwnerRewards(address _owner) public view returns(uint256[] memory) {
        uint256[] memory _ids = new uint256[](5);
        for (uint256 i = 0; i < 5; ) {
            _ids[i] = i;
            unchecked {
                ++i;
            }
        }

        return LibAvalancheValidatorFacet.earned(_owner, _ids);
    }

    /// @dev Get reward per token
    function getRewardPerTokenID(uint256[] memory _ids) public view returns(uint256[] memory) {
        return LibAvalancheValidatorFacet.rewardPerTokenID(_ids);
    }

    /// @dev Get activityPeriod
    function getActivityPeriod() public view returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.activityPeriod;
    }

    /// @dev Get coolingPeriod and coolingPeriodStart
    function getCoolingPeriodAndCoolingPeriodStart() public view returns(uint256, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return (vs.AV.coolingPeriod, vs.AV.coolingPeriodStart);
    }

    /// @dev Get shareCost
    function getShareCost() public view returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.shareCost;
    }

    /// @dev Get if next validator is completed
    function getIsNextValidatorCompleted() public view returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return (vs.AV.isNextValidatorCompleted);
    }

    /// @dev Get QDfees, percentageProportion and nextValidatorCompleted
    function getFeesAndPercentageProportion() public view returns(uint256, uint256, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return (
            vs.AV.QDValidatorFee,
            vs.AV.QDLiquidStakingFee,
            vs.AV.percentageProportion
        );
    }

    /// @dev get roylaty ingo
    function getRoyaltyInfo(uint256 _tokenId) public view returns(address, uint96) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        ValidatorStorage.RoyaltyInfo memory royalty = vs.AV._tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = vs.AV._defaultRoyaltyInfo;
        }

        return (royalty.receiver, royalty.royaltyFraction);
    }

    /// @dev Get avaxToStake
    function getAvaxToStake() public view returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.avaxToStake;
    }

    /// @dev Get refunds stats
    function getRefundsStats() public view returns(uint256, uint256, uint256, uint256, bytes32, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return (
            vs.AV.avaxToRedeem, 
            vs.AV.refundsPercentage, 
            vs.AV.managerRefundsPercentage, 
            vs.AV.refundsAmount, 
            vs.AV.merkletreeRefunds, 
            vs.AV.redeemTime
        );
    }
    /// @dev Get if redeemer has redeemed
    function getHasRedeemed(address _redeemer, uint256 _id) public view returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.redeemed[_id][_redeemer];
    }

    /// @dev Get incentives stats
    function getIncentivesStats() public view returns(uint256, bool, uint256, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return (
            vs.AV.avaxIncentives,
            vs.AV.avaxIncentivesActive,
            vs.AV.rebatePercentageInBPS,
            vs.AV.numberOfRebates
        );
    }

    /// @dev Get rewards per level and QD
    function getIdRewardsAndQDFee() public view returns(uint256, uint256, uint256, uint256, uint256, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return (
            vs.AV.avaxRewardPerLevel[0],
            vs.AV.avaxRewardPerLevel[1],
            vs.AV.avaxRewardPerLevel[2],
            vs.AV.avaxRewardPerLevel[3],
            vs.AV.avaxRewardPerLevel[4],
            vs.AV.QDrewardFee
        );
    }

    /// @dev Get health
    function getOwnerHealth(address _owner, uint256 _id) public view returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.health[_id][_owner];
    }

    /// @dev Get time
    function getTime() public view returns(uint256) {
        return block.timestamp;
    }

    /// @dev get referred address
    function getReferredAddress(address owner) public view returns(address) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.referredAddress[owner];
    }
}