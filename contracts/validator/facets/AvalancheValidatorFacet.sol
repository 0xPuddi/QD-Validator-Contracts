// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";

import { IAvalancheValidatorFacet } from "../interfaces/IAvalancheValidatorFacet.sol";
import { LibAvalancheValidatorFacet } from "../libraries/LibAvalancheValidatorFacet.sol";
import { LibAvalancheValidatorDepositFacet } from "../libraries/LibAvalancheValidatorDepositFacet.sol";
import { LibERC1155Facet } from "../libraries/LibERC1155Facet.sol";

import { LibDiamond } from "../../shared/libraries/LibDiamond.sol";
import { LibMerkleProof } from "../../shared/libraries/LibMerkleProof.sol";
import { LibAddress } from "../../shared/libraries/LibAddress.sol";
import { LibContext } from "../../shared/libraries/LibContext.sol";
import { LibSafeMath } from "../../shared/libraries/LibSafeMath.sol";
import { LibReentrancyGuard } from "../../shared/libraries/LibReentrancyGuard.sol";

/**
 * @dev Implementation of the Avalanche Validator fractionalization and relative mechanics
 */
contract AvalancheValidatorFacet is IAvalancheValidatorFacet, LibReentrancyGuard, LibContext {
    using LibAddress for address;
    using LibSafeMath for uint256;

    /**
     * @dev Check if person with 0 level and rewards on that level messes up the stakingrewards,
     * it shouldn't, but if it does create utility function that directly collects rewards for
     * people that don't have any shares on that specific level
     */
    /// @dev Collect shares rewards
    function collectRewards(uint256[] memory _ids) external nonReentrant returns(bool) {
        address _sender = _msgSender();

        LibAvalancheValidatorFacet.getReward(_sender, _sender, _ids);

        return true;
    }

    /// @dev Redeem refund function - different if burn no reducing max supply := check true
    function redeemRefund(uint256 _amountRedeemed, uint256 _id, bytes32[] calldata _merkleProof) external nonReentrant returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Get values
        address _redeemer = _msgSender();
        LibAvalancheValidatorDepositFacet.checkCoolingTime();

        /// Check merkle tree
        bytes32 leaf = keccak256(abi.encode(_redeemer, _amountRedeemed, _id));
        require(LibMerkleProof.verify(_merkleProof, vs.AV.merkletreeRefunds, leaf), "Merkletree proof not valid");

        /// Check if has redeemed
        require(!vs.AV.redeemed[_id][_redeemer], "You have already redeemed it");
        vs.AV.redeemed[_id][_redeemer] = true;

        /// Send unclaimed rewards of refund to redeemer
        uint256[] memory _id_asSingletonArray = LibERC1155Facet._asSingletonArray(_id);
        LibAvalancheValidatorFacet.getReward(_redeemer, _redeemer, _id_asSingletonArray);

        /// Update values
        vs.AV.refundsAmount -= _amountRedeemed;

        /// Update supplies
        vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[_id] -= _amountRedeemed;
        if (LibAvalancheValidatorFacet.isUnderCoolingPeriod(_redeemer, _id)) {
            vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[_id] -= _amountRedeemed;
        }

        /// Burn share and send money to him - balance zero
        LibERC1155Facet._burn(_redeemer, _id, _amountRedeemed);
        // LibAvalancheValidatorFacet.updateRewards(_redeemer);

        /// Send him the refund
        (bool success, uint256 _avaxToBeRedeemed) = LibAvalancheValidatorFacet.sendRefund(_amountRedeemed, _id, _redeemer);
        require(success, "Unable to send refund");

        /// Event
        emit refundsRedeemed(_redeemer, _amountRedeemed, _avaxToBeRedeemed, block.timestamp);

        /// Success
        return true;
    }

    /// @dev Funds that have not been redeemed
    function manageUnclaimedRefunds(address _refundsUnclaimer, uint256 _amount, uint256 _id, bytes32[] calldata _merkleProof) external nonReentrant returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        address manager = _msgSender();

        /// Time finished
        require(block.timestamp > vs.AV.redeemTime, "Redeeming time is still valid");
        LibAvalancheValidatorDepositFacet.checkCoolingTime();

        /// Check if merkle tree values are correct
        bytes32 leaf = keccak256(abi.encode(_refundsUnclaimer, _amount, _id));
        require(LibMerkleProof.verify(_merkleProof, vs.AV.merkletreeRefunds, leaf), "Merkletree proof not valid");

        /// Check if it has been claimed
        require(!vs.AV.redeemed[_id][_refundsUnclaimer], "You have already redeemed it");
        vs.AV.redeemed[_id][_refundsUnclaimer] = true;

        /// Send unclaimed rewards of refund to redeemer
        uint256[] memory _id_asSingletonArray = LibERC1155Facet._asSingletonArray(_id);
        LibAvalancheValidatorFacet.getReward(_refundsUnclaimer, manager, _id_asSingletonArray);

        /// Update values
        vs.AV.refundsAmount -= _amount;

        /// Update supplies
        vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[_id] -= _amount;
        if (LibAvalancheValidatorFacet.isUnderCoolingPeriod(_refundsUnclaimer, _id)) {
            vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[_id] -= _amount;
        }

        /// Burn unclaimed shares and check if zero
        LibERC1155Facet._burn(_refundsUnclaimer, _id, _amount);

        /// Send him the refund
        (bool success, uint256 _avaxToBeRedeemed) = LibAvalancheValidatorFacet.sendManagerUnclaimedRefund(_amount, _id, manager);
        require(success, "Unable to send refund");

        /// Event
        emit refundsManaged(manager, _amount, _avaxToBeRedeemed, block.timestamp);

        /// Success
        return true;
    }

    /// @dev Give people permission to burn inactive validator shares and claim his rewards
    function manageInactiveValidatorShares(address _inactiveOwner, uint256 _id) external nonReentrant returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Get variables
        address _manager = payable(_msgSender());
        uint256 _inactiveOwnerBalance = LibERC1155Facet.internalBalanceOf(_inactiveOwner, _id);

        /// Contracts and scripts protection
        require(!_manager.isContract(), "Can't be called by a contract");

        /// Require _manager to have a share
        require(
            LibERC1155Facet.internalBalanceOf(_manager, 0) >= 1 && !LibAvalancheValidatorFacet.isUnderCoolingPeriod(_manager, 0) ||
            LibERC1155Facet.internalBalanceOf(_manager, 1) >= 1 && !LibAvalancheValidatorFacet.isUnderCoolingPeriod(_manager, 1) ||
            LibERC1155Facet.internalBalanceOf(_manager, 2) >= 1 && !LibAvalancheValidatorFacet.isUnderCoolingPeriod(_manager, 2) ||
            LibERC1155Facet.internalBalanceOf(_manager, 3) >= 1 && !LibAvalancheValidatorFacet.isUnderCoolingPeriod(_manager, 3) ||
            LibERC1155Facet.internalBalanceOf(_manager, 4) >= 1 && !LibAvalancheValidatorFacet.isUnderCoolingPeriod(_manager, 4),
            "You don't own an active validator share"
        );

        /// Check owner
        require(_inactiveOwnerBalance >= 1, "Address doesn't own anything");

        /// Check inactivity - can you collect only the bool?
        ( , bool _isHealthy) = getPositionHealth(_inactiveOwner, _id);
        require(!_isHealthy, "Owner is active");

        /// Get and send its rewards to manager
        uint256[] memory _id_asSingletonArray = LibERC1155Facet._asSingletonArray(_id);
        LibAvalancheValidatorFacet.getReward(_inactiveOwner, _manager, _id_asSingletonArray);

        /// Update supply
        unchecked {
            vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[_id] -= _inactiveOwnerBalance;
            vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[_id] -= _inactiveOwnerBalance;
        }

        /// Burn inactive share and send rewards to manager
        LibERC1155Facet._burn(_inactiveOwner, _id, _inactiveOwnerBalance);

        /// Emit event to track values
        emit inactiveShareManaged(_manager, _id, block.timestamp);

        /// Success
        return true;
    }

    /// @dev Withdraw QuarryDraw reward fee
    function withdrawQuarryDrawRewardFee() external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Get values
        uint256 _QDrewardFee = vs.AV.QDrewardFee;

        /// Check is fees are present
        require(_QDrewardFee > 0, "No fees to collect");

        /// Update fee
        delete vs.AV.QDrewardFee;

        /// Send rewards from first avalanche validator facet
        LibAddress.sendValue(payable(LibDiamond.contractOwner()), _QDrewardFee);

        /// Success
        return true;
    }

    /// @dev Withdraw $AVAX to stake it into the validator
    function withdrawAvaxToStake() external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Get values
        address payable _payableOwner = payable(LibDiamond.contractOwner());
        uint256 _avaxToStake = vs.AV.avaxToStake;

        /// Check is stake funds are present
        require(_avaxToStake > 0, "No funds to stake");

        /// Update funds
        delete vs.AV.avaxToStake;

        /// Send funds
        LibAddress.sendValue(_payableOwner, _avaxToStake);

        /// Emit track staked avax event
        emit avaxWithdrawnToStake(_avaxToStake, _payableOwner, block.timestamp);

        /// Success
        return true;
    }

    /// @dev Withdraw incentives 
    function withdrawIncentives() external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Get values
        uint256 _numberOfRebates = vs.AV.numberOfRebates;

        /// Check is incentives are active
        require(_numberOfRebates == 0, "Cant withdraw incentives");

        /// Update values
        delete vs.AV.avaxIncentivesActive;
        delete vs.AV.rebatePercentageInBPS;
        delete vs.AV.numberOfRebates;
        delete vs.AV.avaxIncentives;

        /// Emit track staked avax event
        emit incentivesStoppedAndWithdrawn(_numberOfRebates, LibDiamond.contractOwner(), block.timestamp);

        /// Success
        return true;
    }

    /// @dev Get health of a position
    function getPositionHealth(address _owner, uint256 _id) view public returns(uint256, bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Get variables
        uint256 _ownerHealth = vs.AV.health[_id][_owner];

        /// Health not initialized
        require(_ownerHealth != 0, "Owner doesn't have shares");

        if (LibAvalancheValidatorFacet.isUnderCoolingPeriod(_owner, _id)) {
            uint256 _remainingCoolingPeriod = _ownerHealth - block.timestamp;

            return(_remainingCoolingPeriod, true);
        } else {
            uint256 _activityPeriod = vs.AV.activityPeriod;
            uint256 remainingTime = block.timestamp - _ownerHealth;

            bool _isHealthy = _activityPeriod >= remainingTime;

            if (_isHealthy) {
                return(_activityPeriod - remainingTime, _isHealthy);
            } else {
                return(0, _isHealthy);
            }
        }
    }

    /// @dev External call to {cleanRedeemedMapping}
    function externalCleanRedeemedMapping(uint256[] memory _ids) external nonReentrant {
        LibAvalancheValidatorFacet.cleanRedeemedMapping(_ids);
    }
}