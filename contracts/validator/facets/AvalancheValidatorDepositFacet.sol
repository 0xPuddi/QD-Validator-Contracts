// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";

import { IAvalancheValidatorDepositFacet } from "../interfaces/IAvalancheValidatorDepositFacet.sol";
import { LibAvalancheValidatorDepositFacet } from "../libraries/LibAvalancheValidatorDepositFacet.sol";
import { LibAvalancheValidatorFacet } from "../libraries/LibAvalancheValidatorFacet.sol";
import { LibERC1155Facet } from "../libraries/LibERC1155Facet.sol";

import { LibDiamond } from "../../shared/libraries/LibDiamond.sol";
import { LibReentrancyGuard } from "../../shared/libraries/LibReentrancyGuard.sol";
import { LibAddress } from "../../shared/libraries/LibAddress.sol";
import { LibContext } from "../../shared/libraries/LibContext.sol";
import { IERC20 } from "../../shared/interfaces/IERC20.sol";

contract AvalancheValidatorDepositFacet is IAvalancheValidatorDepositFacet, LibContext, LibReentrancyGuard {
    using LibAddress for address;

    /// @dev Add incentives to mint shares
    function depositIncentives(uint256 _rebatePercentageInBPS, uint256 _numberOfRebates) external payable nonReentrant returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        uint256 _percentageProportion = vs.AV.percentageProportion;

        /// Check incentives are not active
        require(!vs.AV.avaxIncentivesActive, "Incentives are already active");

        /// Check rebates don't go over supply
        require(vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[0] + _numberOfRebates <= vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[0], "Too many incentivized");

        /// Check percentage
        require(_rebatePercentageInBPS <= _percentageProportion, "Over 100%");

        /// Check rebates percentage, number and incentives correspond
        require(((vs.AV.shareCost * _numberOfRebates) * _rebatePercentageInBPS) / _percentageProportion <= msg.value, "Wrong composition or value");

        /// Update values
        vs.AV.avaxIncentivesActive = true;
        vs.AV.rebatePercentageInBPS = _rebatePercentageInBPS;
        vs.AV.numberOfRebates = _numberOfRebates;

        /// Update funds
        vs.AV.avaxIncentives = msg.value;

        /// Emit track incentives event
        emit incentivesDeposited(_rebatePercentageInBPS, _numberOfRebates, _msgSender(), block.timestamp);

        /// Success
        return true;
    }

    /// @dev Deposit funds for refund at 80% of their initial value
    function depositRefunds(uint256[5] memory _amount, uint256[5] memory _IDs, bytes32 _merkletree, uint256 _redeemTimeInSeconds) external payable returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Check input reliability
        require(
            _IDs.length == _amount.length &&
            _IDs.length <= 5,
            "Wrong input composition"
        );

        /// Get variables
        (
            uint256 _totPonderatedValue,
            uint256 _totAmount
        ) = LibAvalancheValidatorDepositFacet.calculateTotPonderateValueAndAmount(
            _amount,
            vs.AV.percentageProportion,
            vs.AV.refundsPercentage,
            vs.AV.shareCost
        );

        /// Check if amount is correct - in wei
        require(_totPonderatedValue <= msg.value , "Not enough to refund all people");

        /// Update redeems money and merkle tree
        vs.AV.avaxToRedeem = msg.value;
        vs.AV.merkletreeRefunds = _merkletree; /// composition: owner, amount, id
        vs.AV.redeemTime = block.timestamp + _redeemTimeInSeconds;
        vs.AV.refundsAmount = _totAmount;
        vs.AV.redeemsActive = true;

        /// Emit refunds deposited event
        emit refundsDeposited(_amount, msg.value, block.timestamp + _redeemTimeInSeconds);

        /// Success
        return true;
    }

    /// @dev Deposit rewards from validation and liquid stakig, then distribute it between levels and QD
    function depositRewards(uint256 _liquidStakigRewardsInWei, uint256[] memory _ids) external payable nonReentrant returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Clear coolig supply
        require(_ids.length == 5, "IDs length mismatch");
        for (uint256 i = 0; i < 5; ) {
            delete vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[i];
            require(_ids[i] == i, "IDs mismatch");
            unchecked {
                ++i;
            }
        }

        /// Check someone here
        require(LibAvalancheValidatorDepositFacet.getTotalCurrentActiveSupplyPondered() != 0, "0 active supplies");
        require(_liquidStakigRewardsInWei <= msg.value, 'Liquid Staking Rewards > 100%');

        /// Get variables
        (
            uint256 _singleStakeAmountLVL1,
            uint256 _singleStakeAmountLVL2,
            uint256 _singleStakeAmountLVL3,
            uint256 _singleStakeAmountLVL4,
            uint256 _singleStakeAmountLVL5
        ) = LibAvalancheValidatorDepositFacet.getSingleCurrentActiveSupplies();
        uint256 _percentageProportion = vs.AV.percentageProportion;

        /// Update rewards
        uint256 _QDrewardStakingFee = (_liquidStakigRewardsInWei * vs.AV.QDLiquidStakingFee) / _percentageProportion;
        uint256 _QDrewardValidationFee = ((msg.value - _liquidStakigRewardsInWei) * vs.AV.QDValidatorFee) / _percentageProportion;
        vs.AV.QDrewardFee += _QDrewardValidationFee;
        vs.AV.QDrewardFee += _QDrewardStakingFee;

        uint256 _remainingFractionRewards = (msg.value - _QDrewardValidationFee - _QDrewardStakingFee) / LibAvalancheValidatorDepositFacet.getTotalCurrentActiveSupplyPondered();

        vs.AV.avaxRewardPerLevel[0] += _remainingFractionRewards * _singleStakeAmountLVL1;
        vs.AV.avaxRewardPerLevel[1] += _remainingFractionRewards * _singleStakeAmountLVL2;
        vs.AV.avaxRewardPerLevel[2] += _remainingFractionRewards * _singleStakeAmountLVL3;
        vs.AV.avaxRewardPerLevel[3] += _remainingFractionRewards * _singleStakeAmountLVL4;
        vs.AV.avaxRewardPerLevel[4] += _remainingFractionRewards * _singleStakeAmountLVL5;

        /// Set rewards distribution
        LibAvalancheValidatorFacet.notifyRewardAmount(_ids);

        /// Emit funds deposited
        emit validatorFundsDeposited(msg.value, msg.sender, block.timestamp);
        emit liquidStakingFundsDeposited(_liquidStakigRewardsInWei, msg.sender, block.timestamp);

        /// Success
        return true;
    }

    /// @dev Mint an Avalanche Validator level 1 share from contract with AVAX native
    function mintAvalancheValidatorShareAVAX(uint256 _amount, bytes memory _data) external payable nonReentrant returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Check supply
        require(vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[0] + _amount <= vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[0], "Max supply reached");
        require(_amount > 0, "NO_AMOUNT");

        /// Introduce incentives
        uint256 _shareCost = vs.AV.shareCost;
        bool _avaxIncentivesActive = vs.AV.avaxIncentivesActive;
        uint256  _numberOfRebates = vs.AV.numberOfRebates;

        if (_avaxIncentivesActive) {
            require(_amount <= _numberOfRebates, "NO_REBATES_SHARES_AVAILABLE");

            _shareCost = _shareCost - ((_shareCost * vs.AV.rebatePercentageInBPS) / vs.AV.percentageProportion);
            vs.AV.numberOfRebates -= _amount;
        }

        /// Check txn value
        require(msg.value >= _amount * _shareCost, "Not enough AVAX");

        /// Get variables
        address _minter = _msgSender();

        /// Deposit payment
        if (_avaxIncentivesActive) {
            uint256 _avaxIncentives = vs.AV.avaxIncentives;
            /// Update values
            vs.AV.avaxIncentives = _avaxIncentives - ((_avaxIncentives * _amount) / _numberOfRebates);
            vs.AV.avaxToStake += msg.value + ((_avaxIncentives * _amount) / _numberOfRebates);
        } else {
            vs.AV.avaxToStake += msg.value;
        }

        /// Update supply
        vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[0] += _amount;

        /// Check Quarry Draw fee
        LibAvalancheValidatorDepositFacet.checkQDValidatorFee();

        /// Check and update health
        require(LibAvalancheValidatorDepositFacet.setLVL1MinterHealth(_minter, block.timestamp, _amount), "Health not setted correctly");

        /// Mint shares
        LibERC1155Facet._mint(_minter, 0, _amount, _data);

        /// Event
        emit avalancheValidatorShareSold(_minter, _amount, block.timestamp);

        /// Success
        return true;
    }

    /// @dev Burn share
    function burnShares(uint256[] memory ids, uint256[] memory amounts) external returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Check length
        require(ids.length == amounts.length, "ids, amounts length mismatch");
        LibAvalancheValidatorDepositFacet.checkCoolingTime();

        /// Update and send rewards 
        LibAvalancheValidatorFacet.getReward(msg.sender, msg.sender, ids);

        /// Burn shares and check balance
        LibERC1155Facet._burnBatch(msg.sender, ids, amounts);

        /// Update values
        for (uint256 i = 0; i < ids.length; ) {
            unchecked {
                vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[ids[i]] -= amounts[i];
                vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[ids[i]] -= amounts[i];
                if (LibAvalancheValidatorFacet.isUnderCoolingPeriod(msg.sender, ids[i])) {
                    vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[ids[i]] -= amounts[i];
                }
                ++i;
            }
        }

        /// Zero balance update
        for (uint256 i = 0; i < ids.length; ) {
            LibAvalancheValidatorFacet.toZeroBalanceUpdate(msg.sender, ids[i]);
            unchecked {
                ++i;
            }
        }
        
        /// Event
        emit sharesBurned(msg.sender, ids, amounts);

        /// Success
        return true;
    }
}