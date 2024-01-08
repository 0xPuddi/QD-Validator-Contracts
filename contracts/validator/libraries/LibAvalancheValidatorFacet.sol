// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";

import { LibDiamond } from "../../shared/libraries/LibDiamond.sol";
import { LibERC1155Facet } from "../libraries/LibERC1155Facet.sol";
import { LibAddress } from "../../shared/libraries/LibAddress.sol";
import { ActualLibContext } from "../../shared/libraries/LibContext.sol";

library LibAvalancheValidatorFacet {
    using LibAddress for address;

    /// @dev Update reward of owner based on ID
    function updateRewards(address _account, uint256[] memory _ids) internal {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        for (uint256 i = 0; i < _ids.length; ) {
            if (isUnderCoolingPeriod(_account, _ids[i])) {
                return;
            }
            unchecked {
                ++i;
            }
        }

        uint256[] memory _rewardPerTokenID = rewardPerTokenID(_ids);
        uint256[] memory _earned = earned(_account, _ids);

        for (uint256 i = 0; i < _ids.length; ) {
            vs.AV.updatedAt[_ids[i]] = lastTimeRewardApplicable();
            vs.AV.rewardPerTokenStored[_ids[i]] = _rewardPerTokenID[i];

            if (_account != address(0)) {
                vs.AV.avaxRewardPerLevel[_ids[i]] -= (_earned[i] - vs.AV.rewards[_ids[i]][_account]);
                vs.AV.rewards[_ids[i]][_account] = _earned[i];

                vs.AV.userRewardPerTokenPaid[_ids[i]][_account] = _rewardPerTokenID[i];
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Get reward per token ID
    function rewardPerTokenID(uint256[] memory _ids) internal view returns (uint256[] memory _rewardPerTokenID) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        uint256[] memory fixed_rewardPerTokenID = new uint256[](_ids.length);

        for (uint256 i = 0; i < _ids.length; ) {
            if (vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[_ids[i]] - vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[_ids[i]] == 0) {
                fixed_rewardPerTokenID[i] = vs.AV.rewardPerTokenStored[_ids[i]];
            } else {
                fixed_rewardPerTokenID[i] =
                vs.AV.rewardPerTokenStored[_ids[i]] +
                (
                    vs.AV.rewardRate[_ids[i]] *
                    (
                        lastTimeRewardApplicable() - vs.AV.updatedAt[_ids[i]]
                    ) * 1e18
                ) /
                (
                    vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[_ids[i]] -
                    vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[_ids[i]]
                );
            }
            unchecked {
                ++i;
            }
        }

        _rewardPerTokenID = fixed_rewardPerTokenID;
    }

    /// @dev Get amount earned from user - getter
    function earned(address _account, uint256[] memory _ids) internal view returns(uint256[] memory _earnings) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        uint256[] memory _rewardPerTokenID = rewardPerTokenID(_ids);
        uint256[] memory fixed_earnings = new uint256[](_ids.length);

        for (uint256 i = 0; i < _ids.length; ) {
            if (_account == address(0)) {
                fixed_earnings[i] = 0;
            } else {
                fixed_earnings[i] =
                (
                    (
                        LibERC1155Facet.internalBalanceOf(_account, _ids[i])
                        * (_rewardPerTokenID[i] - vs.AV.userRewardPerTokenPaid[_ids[i]][_account])
                    ) / 1e18
                ) + vs.AV.rewards[_ids[i]][_account];
            }
            unchecked {
                ++i;
            }
        }

        _earnings = fixed_earnings;
    }

    /// @dev Get msg.sender rewards
    function getReward(address _from, address _to, uint256[] memory _ids) internal {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        updateRewards(_from, _ids);

        for (uint256 i = 0; i < _ids.length; ) {
            uint256 _reward = vs.AV.rewards[_ids[i]][_from];

            if (_reward > 0) {
                delete vs.AV.rewards[_ids[i]][_from];

                // Add to earned referral
                uint256 rewardsReferral = 0;
                address referral = vs.AV.referredAddress[_from];
                if (referral != address(0)) {
                    rewardsReferral = _reward * vs.AV.referralRewards[vs.AV.referralNumber[referral]] / vs.AV.percentageProportion;
                    vs.AV.rewards[_ids[i]][referral] += rewardsReferral;
                }

                LibAddress.sendValue(payable(_to), (_reward - rewardsReferral));
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Set rewards duration
    function setRewardsDuration(uint256 _duration) internal {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        require(vs.AV.finishAt < block.timestamp, "reward duration not finished");

        vs.AV.duration = _duration;
    }

    /// @dev Notify the reward amount of the pool
    /**
     * Create system that on notifyRewardAmount call, it updates the cooling period of new mints, without needing to block
     * and require a strict updating period????
     * once period is finished and rewards needs an update, thus new staking period is coming cooling period is not existing,
     * thus give no cooling period, until we re-update it.
     */
    function notifyRewardAmount(uint256[] memory _ids) internal {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        
        uint256 _coolingPeriodStart = vs.AV.coolingPeriodStart;
        _coolingPeriodStart = block.timestamp;

        updateRewards(address(0), _ids);

        uint256 _duration = vs.AV.duration;
        uint256[5] memory _amounts = getAvaxRewards();

        for (uint256 i = 0; i < 5; ) {
            if (vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[i] - vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[i] == 0) {
                vs.AV.rewardRate[i] = _amounts[i] / _duration;

                delete vs.AV.updatedAt[i];

                require(vs.AV.rewardRate[i] == 0, "reward rate != 0");
            } else {
                // If called before finishAt, _amounts stores all remaining rewards in the pool
                vs.AV.rewardRate[i] = _amounts[i] / _duration;

                require(vs.AV.rewardRate[i] > 0, "reward rate = 0");
                require(
                    vs.AV.rewardRate[i] * _duration <= _amounts[i],
                    "reward amount > balance"
                );

                vs.AV.updatedAt[i] = block.timestamp;
            }
            unchecked {
                ++i;
            }
        }

        vs.AV.finishAt = block.timestamp + _duration;
    }

    /// @dev Get the last time reward applicable
    function lastTimeRewardApplicable() internal view returns (uint) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return _min(vs.AV.finishAt, block.timestamp);
    }
    /// @dev Get min between x and y
    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    /// @dev Get all avax rewards per level
    function getAvaxRewards() internal view returns(uint256[5] memory _avaxRewards) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        for (uint256 i = 0; i < 5; ) {
            _avaxRewards[i] = vs.AV.avaxRewardPerLevel[i];
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Get current owner total token supply per level
    function getOwnerTotalSupply(address _owner) internal view returns(uint256[5] memory _ownerTotalSupply) {
        for (uint256 i = 0; i < 5; ) {
            _ownerTotalSupply[i] = LibERC1155Facet.internalBalanceOf(_owner, i);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Check if owner and id is under cooling period, if he is @return true, if not or no shares @return false
    function isUnderCoolingPeriod(address _owner, uint256 _id) internal view returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Check cooling period
        if (block.timestamp < vs.AV.health[_id][_owner]) {
            return true;
        } else {
            return false;
        }
    }

    /// @dev Update a balance that has remained with zero tokens, rewards update need to be made beforehand - return necessary? check when used, because afterTransfer might be sufficient
    function toZeroBalanceUpdate(address _owner, uint256 _id) internal returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        bool isZero;

        /// Check if it is zero
        if (LibERC1155Facet.internalBalanceOf(_owner, _id) == 0) {
            isZero = true;
        }

        /// Require it
        if (isZero) {
            /// Update parameters
            delete vs.AV.health[_id][_owner];
            delete vs.AV.holder[_id][_owner];
        }

        /// Success
        return true;
    }

    /// @dev Send refund to redeemer
    function sendRefund(uint256 _amountRedeemed, uint256 _id, address _redeemer) internal returns(bool, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        uint256 _avaxToBeRedeemed;
        uint16[5] memory _proportionID = [1, 10, 100, 1000, 10000];
        
        for (uint256 i = 0; i < _proportionID.length; ) {
            if (_id == i) {
                _avaxToBeRedeemed = 
                (
                    (
                        _amountRedeemed * vs.AV.shareCost * _proportionID[i]
                    ) * vs.AV.refundsPercentage
                ) / vs.AV.percentageProportion;
                break;
            }
            unchecked {
                ++i;
            }
        }

        unchecked {
            vs.AV.avaxToRedeem -= _avaxToBeRedeemed;
        }
    
        LibAddress.sendValue(payable(_redeemer), _avaxToBeRedeemed);

        return (true, _avaxToBeRedeemed);
    }

    /// @dev Get and send unclaimed refunds to manager
    function sendManagerUnclaimedRefund(uint256 _amount, uint256 _id, address _manager) internal returns(bool, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        uint256 _percentageProportion = vs.AV.percentageProportion;
        uint256 _avaxToBeRedeemed;
        uint16[5] memory _proportionID = [1, 10, 100, 1000, 10000];

        for (uint256 i = 0; i < _proportionID.length; ) {
            if (_id == i) {
                _avaxToBeRedeemed =
                (
                    (
                        _amount * vs.AV.shareCost * _proportionID[i]
                    ) * vs.AV.refundsPercentage
                ) / _percentageProportion;
                break;
            }
            unchecked {
                ++i;
            }
        }

        unchecked {
            vs.AV.avaxToRedeem -= _avaxToBeRedeemed;
        }
        
        uint256 _managerRefundsPercentage = vs.AV.managerRefundsPercentage;

        LibAddress.sendValue(payable(_manager), ((_avaxToBeRedeemed * _managerRefundsPercentage) / _percentageProportion));
        vs.AV.avaxToStake += (_avaxToBeRedeemed * (_percentageProportion - _managerRefundsPercentage) / _percentageProportion);

        return(true, _avaxToBeRedeemed);
    }

    /// @dev Clean redeemed mapping
    function cleanRedeemedMapping(uint256[] memory _ids) internal returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        require(!vs.AV.redeemsActive, "Redeems not finished");
        for (uint256 i = 0; i < _ids.length; ) {
            delete vs.AV.redeemed[_ids[i]][msg.sender];
            unchecked {
                ++i;
            }
        }
        return true;
    }
}