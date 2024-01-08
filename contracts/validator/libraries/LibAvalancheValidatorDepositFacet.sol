// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";

import { LibERC1155Facet } from "../libraries/LibERC1155Facet.sol";
import { LibAvalancheValidatorFacet } from "../libraries/LibAvalancheValidatorFacet.sol";

library LibAvalancheValidatorDepositFacet {
    /// @dev Get current SFTs supply
    function getCurrentSupplies() view internal returns(uint256[5] memory AV_SUPPLIES) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        for (uint256 i = 0; i < 5; ) {
            AV_SUPPLIES[i] = vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[i];
            unchecked {
                ++i;
            }
        }
    }
    /// @dev Retrive total current supply
    function getTotalCurrentSupply() view internal returns(uint256) {
        uint256[5] memory AV_SUPPLIES = getCurrentSupplies();
        return AV_SUPPLIES[0] + AV_SUPPLIES[1] + AV_SUPPLIES[2] + AV_SUPPLIES[3] + AV_SUPPLIES[4];
    }
    /// @dev Retrive current active supply pondered amount
    function getTotalCurrentSupplyPondered() internal view returns(uint256 _currentStakeAmount) {
        /// Get variables
        uint256[5] memory AV_SUPPLIES = getCurrentSupplies();

        /// Calculate it
        _currentStakeAmount = AV_SUPPLIES[0] * 1 + AV_SUPPLIES[1] * 10 + AV_SUPPLIES[2] * 100 + AV_SUPPLIES[3] * 1000 + AV_SUPPLIES[4] * 10000;
    }
    /// @dev Retrive single current supplies
    function getSingleCurrentSupplies() internal view returns
    (
        uint256 _singleStakeAmountLVL1,
        uint256 _singleStakeAmountLVL2,
        uint256 _singleStakeAmountLVL3,
        uint256 _singleStakeAmountLVL4,
        uint256 _singleStakeAmountLVL5
    ) {
        /// Get variables
        uint256[5] memory AV_SUPPLIES = getCurrentSupplies();

        /// Calculate it
        _singleStakeAmountLVL1 = AV_SUPPLIES[0] * 1;
        _singleStakeAmountLVL2 = AV_SUPPLIES[1] * 10;
        _singleStakeAmountLVL3 = AV_SUPPLIES[2] * 100;
        _singleStakeAmountLVL4 = AV_SUPPLIES[3] * 1000;
        _singleStakeAmountLVL5 = AV_SUPPLIES[4] * 10000;
    }

    /// @dev Get current active SFTs supply
    function getCurrentActiveSupplies() view internal returns(uint256[5] memory AV_ACTIVE_SUPPLIES) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        for (uint256 i = 0; i < 5; ) {
            AV_ACTIVE_SUPPLIES[i] = vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[i] - vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[i];
            unchecked {
                ++i;
            }
        }
    }
    /// @dev Retrive total current active supply
    function getTotalCurrentActiveSupply() view internal returns(uint256) {
        uint256[5] memory AV_ACTIVE_SUPPLIES = getCurrentActiveSupplies();
        return AV_ACTIVE_SUPPLIES[0] + AV_ACTIVE_SUPPLIES[1] + AV_ACTIVE_SUPPLIES[2] + AV_ACTIVE_SUPPLIES[3] + AV_ACTIVE_SUPPLIES[4];
    }
    /// @dev Retrive current active supply pondered amount
    function getTotalCurrentActiveSupplyPondered() internal view returns(uint256 _currentStakeAmount) {
        /// Get variables
        uint256[5] memory AV_ACTIVE_SUPPLIES = getCurrentActiveSupplies();

        /// Calculate it
        _currentStakeAmount = AV_ACTIVE_SUPPLIES[0] * 1 + AV_ACTIVE_SUPPLIES[1] * 10 + AV_ACTIVE_SUPPLIES[2] * 100 + AV_ACTIVE_SUPPLIES[3] * 1000 + AV_ACTIVE_SUPPLIES[4] * 10000;
    }
    /// @dev Retrive single active stake amount
    function getSingleCurrentActiveSupplies() internal view returns
    (
        uint256 _singleStakeAmountLVL1,
        uint256 _singleStakeAmountLVL2,
        uint256 _singleStakeAmountLVL3,
        uint256 _singleStakeAmountLVL4,
        uint256 _singleStakeAmountLVL5
    ) {
        /// Get variables
        uint256[5] memory AV_ACTIVE_SUPPLIES = getCurrentActiveSupplies();

        /// Calculate it
        _singleStakeAmountLVL1 = AV_ACTIVE_SUPPLIES[0] * 1;
        _singleStakeAmountLVL2 = AV_ACTIVE_SUPPLIES[1] * 10;
        _singleStakeAmountLVL3 = AV_ACTIVE_SUPPLIES[2] * 100;
        _singleStakeAmountLVL4 = AV_ACTIVE_SUPPLIES[3] * 1_000;
        _singleStakeAmountLVL5 = AV_ACTIVE_SUPPLIES[4] * 10_000;
    }

    /// @dev Take array amount, share cost, percentageproportion and refunds percentage to calculate tot Amount and totPonderatedValue
    function calculateTotPonderateValueAndAmount(
        uint256[5] memory _amount,
        uint256 _percentageProportion,
        uint256 _refundsPercentage,
        uint256 _shareCost
    ) internal pure returns(uint256 _totPonderatedValue, uint256 _totAmount) {
        _totPonderatedValue =
        (
            (
                _amount[0] * _shareCost +
                _amount[1] * _shareCost * 10 +
                _amount[2] * _shareCost * 100 +
                _amount[3] * _shareCost * 1000 +
                _amount[4] * _shareCost * 10000
            ) * _refundsPercentage
        ) / _percentageProportion;
        _totAmount = _amount[0] + _amount[1] + _amount[2] + _amount[3] + _amount[4];
    }

    /// @dev Check and adapt QuarryDraw validator fee
    function checkQDValidatorFee() internal {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Get variables
        uint256 _currentStakeAmount = getTotalCurrentActiveSupplyPondered();
        uint256 _QDValidatorFee = vs.AV.QDValidatorFee;

        if (!vs.AV.isNextValidatorCompleted) {
            /// Check timeline and adjust it
            if (_currentStakeAmount <= 600000 && _QDValidatorFee != 1000) {
                vs.AV.QDValidatorFee = 1000;
            }
            if (600000 <= _currentStakeAmount && _currentStakeAmount <= 1200000 && _QDValidatorFee != 900) {
                vs.AV.QDValidatorFee = 900;
            }
            if (1200000 <= _currentStakeAmount && _currentStakeAmount <= 1800000  && _QDValidatorFee != 800) {
                vs.AV.QDValidatorFee = 800;
            }
            if (1800000 <= _currentStakeAmount && _currentStakeAmount <= 2400000 && _QDValidatorFee != 600) {
                vs.AV.QDValidatorFee = 600;
            }
            if (2400000 <= _currentStakeAmount && _currentStakeAmount <= 3000000  && _QDValidatorFee != 500) {
                vs.AV.QDValidatorFee = 500;
            }
        } else {
            /// Check timeline and adjust it
            if (_currentStakeAmount <= 600000 && _QDValidatorFee != 250) {
                vs.AV.QDValidatorFee = 250;
            }
            if (600000 <= _currentStakeAmount && _currentStakeAmount <= 1200000 && _QDValidatorFee != 225) {
                vs.AV.QDValidatorFee = 225;
            }
            if (1200000 <= _currentStakeAmount && _currentStakeAmount <= 1800000  && _QDValidatorFee != 200) {
                vs.AV.QDValidatorFee = 200;
            }
            if (1800000 <= _currentStakeAmount && _currentStakeAmount <= 2400000 && _QDValidatorFee != 150) {
                vs.AV.QDValidatorFee = 150;
            }
            if (2400000 <= _currentStakeAmount && _currentStakeAmount <= 3000000  && _QDValidatorFee != 125) {
                vs.AV.QDValidatorFee = 125;
            }
        }
    }

    ///@dev Set health for LVL1 mint
    function setLVL1MinterHealth(address _minter, uint256 _time, uint256 _amount) internal returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        uint256 _coolingTime;

        for (uint256 i = 0; i < 5; ) {
            if (vs.AV.holder[i][_minter]) {
                if (LibAvalancheValidatorFacet.isUnderCoolingPeriod(_minter, i)) { // Cooling period minter
                    vs.AV.holder[0][_minter] = true;
                    vs.AV.health[0][_minter] = checkCoolingTime();
                    vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[0] += _amount;
                    return true;
                } else { // healty minter
                    vs.AV.holder[0][_minter] = true;
                    vs.AV.health[0][_minter] = _time;
                    uint256[] memory _id_asSingletonArray = LibERC1155Facet._asSingletonArray(0);
                    LibAvalancheValidatorFacet.updateRewards(_minter, _id_asSingletonArray);
                    return true;
                }
            } else if (i == 4) { // New minter
                vs.AV.holder[0][_minter] = true;
                _coolingTime = checkCoolingTime();
                vs.AV.health[0][_minter] = _coolingTime;
                if (_coolingTime > block.timestamp) vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[0] += _amount;
                return true;
            }
            unchecked {
                ++i;
            }
        }
        
        return false;
    }

    /// @dev Check that the cooling period is not under the current time
    function checkCoolingTime() internal view returns(uint256 _actualCoolingTime) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Get values
        uint256 _coolingPeriod = vs.AV.coolingPeriod;
        uint256 _coolingPeriodStart = vs.AV.coolingPeriodStart;
        uint256 _time = block.timestamp;

        /// Update period if needed
        if (_time >= _coolingPeriodStart + _coolingPeriod) {
            /// Transit period
            _actualCoolingTime = _time;
        } else {
            /// Calculate period
            _actualCoolingTime = _coolingPeriodStart + _coolingPeriod;
        }
    }
}