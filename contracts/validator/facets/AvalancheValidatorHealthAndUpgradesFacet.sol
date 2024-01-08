// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";

import { IAvalancheValidatorHealthAndUpgradesFacet } from "../interfaces/IAvalancheValidatorHealthAndUpgradesFacet.sol";
import { LibAvalancheValidatorDepositFacet } from "../libraries/LibAvalancheValidatorDepositFacet.sol";

import { LibDiamond } from "../../shared/libraries/LibDiamond.sol";
import { LibERC1155Facet } from "../libraries/LibERC1155Facet.sol";
import { LibAvalancheValidatorFacet } from "../libraries/LibAvalancheValidatorFacet.sol";
import { LibReentrancyGuard } from "../../shared/libraries/LibReentrancyGuard.sol";
import { LibContext } from "../../shared/libraries/LibContext.sol";
import { LibAddress } from "../../shared/libraries/LibAddress.sol";

contract AvalancheValidatorHealthAndUpgradesFacet is IAvalancheValidatorHealthAndUpgradesFacet, LibContext, LibReentrancyGuard {
    using LibAddress for address;

    /// @dev Clear every refund states and withdraw remaining avax
    function withdrawRefunds() external nonReentrant returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Get values
        uint256 _redeemTime = vs.AV.redeemTime;

        /// No refunds
        require(_redeemTime > 0, 'No refunds active');

        /// Time finished
        require(block.timestamp > _redeemTime, "Redeeming time is still valid");

        /// All refunds claimed, properbly or managed
        require(vs.AV.refundsAmount == 0, "Not all refunds claimed");

        /// Restart values
        delete vs.AV.merkletreeRefunds;
        delete vs.AV.redeemTime;
        delete vs.AV.avaxToRedeem;
        delete vs.AV.redeemsActive;

        /// Success
        return true;
    }

    /// @dev Increase level of the Avalanche Validator by burning a lower level and minting a higher one (10 lvlx = 1 lvlx+1)
    function upgradeAvalancheValidatorLevel(uint256[] memory _ids, uint256[] memory _numberOfUpgrades) external nonReentrant returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Check input reliability
        require(
            _ids.length == _numberOfUpgrades.length && 
            1 <= _ids.length &&
            _ids.length <= 4,
            "Wrong input composition"
        );

        /// Check last ID and fill update ids
        uint256[] memory fixed_ids = new uint256[](_ids.length + 1);
        for (uint i = 0; i < _ids.length; ) {
            require(_ids[i] != 4, "Lvl 5 is maximum level allowed");
            require(_numberOfUpgrades[i] > 0, "No upgrades to make");
            if (i + 1 == _ids.length) {
                fixed_ids[i] = _ids[i];
                fixed_ids[i + 1] = _ids.length;
            } else {
                fixed_ids[i] = _ids[i];
            }

            unchecked {
                ++i;
            }
        }

        /// Get variables
        address _minter = _msgSender();

        LibAvalancheValidatorFacet.updateRewards(_minter, fixed_ids);

        /// Upgrade level
        for(uint256 i = 0; i < _ids.length; ) {
            /// Get variables
            uint256 _ID = _ids[i];
            uint256 next_ID = _ID + 1;
            uint256 _numberOfUpgrade = _numberOfUpgrades[i];

            /// Check balanche
            require(LibERC1155Facet.internalBalanceOf(_minter, _ID) >= _numberOfUpgrade*10, "Not enough shares");
                
            /// Check next level supply
            require(vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[next_ID] + _numberOfUpgrade <= vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[next_ID], "Exceedes next level max supply");
                
            /// Update supplies
            unchecked {
                vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[_ID] -= _numberOfUpgrade*10;
                vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[_ID] -= _numberOfUpgrade*10;
                vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[next_ID] += _numberOfUpgrade;
            }
            if (LibAvalancheValidatorFacet.isUnderCoolingPeriod(_minter, _ID)) {
                unchecked{
                    vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[_ID] -= _numberOfUpgrade*10;
                    vs.AV.AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY[next_ID] += _numberOfUpgrade;
                }   
            }

            /// Update key holders
            vs.AV.holder[next_ID][_minter] = true;

            /// Same health as previous level if cooling it gets over to the next level
            vs.AV.health[next_ID][_minter] = vs.AV.health[_ID][_minter];

            /// Burn and Mint shares
            LibERC1155Facet._burn(_minter, _ID, _numberOfUpgrade*10);

            /// Zero balance update
            LibAvalancheValidatorFacet.toZeroBalanceUpdate(_minter, _ID);

            /// Mint shares
            LibERC1155Facet._mint(_minter, next_ID, _numberOfUpgrade, "");

            /// Event
            emit upgradedShares(_minter, next_ID, _numberOfUpgrade, _ID, _numberOfUpgrade*10, block.timestamp);
                
            unchecked {
            ++i;
            }
        }

        /// Success
        return true;
    }

    /// @dev Investor's input to update his activity and his rewards
    function refreshAvalancheValidatorSharesHealth(uint256[] memory _ids) external returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        
        address _owner = _msgSender();

        /// Check is not on cooling
        for (uint256 i = 0; i < _ids.length; ) {
            require(!LibAvalancheValidatorFacet.isUnderCoolingPeriod(_owner, _ids[i]), "Under cooling period");
            require(LibERC1155Facet.internalBalanceOf(_owner, _ids[i]) >= 1, "No shares");
            unchecked {
                ++i;
            }
        }

        /// Refresh health
        for (uint256 i = 0; i < _ids.length; ) {
            
            vs.AV.health[_ids[i]][_owner] = block.timestamp;

            unchecked {
                ++i;
            }
        }

        /// Update rewards
        LibAvalancheValidatorFacet.updateRewards(_owner, _ids);

        /// Success
        return true;
    }

    /// @dev Add and remove user referred address
    function manageReferralAddress(address referral) external returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        // Referring an address override the old one, to clean your referral => address(0)
        address oldReferral = vs.AV.referredAddress[msg.sender];

        // Can't update same
        require(referral != oldReferral, "SAME_ADDRESS");

        vs.AV.referredAddress[msg.sender] = referral;

        if (oldReferral != address(0)) {
            vs.AV.referralNumber[oldReferral] -= 1;
        } else if (referral != address(0)) {
            vs.AV.referralNumber[referral] += 1;
            require(vs.AV.referralNumber[referral] <= 15, 'MAX_REFERRALS_AMOUNT_REACHED');
        }

        emit ReferralAddressManaged(msg.sender, referral, block.timestamp);

        return true;
    }
}