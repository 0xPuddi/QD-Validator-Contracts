// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface IAvalancheValidatorHealthAndUpgradesFacet {
    /// @dev Share upgrade event
    event upgradedShares(
        address indexed owner,
        uint256 indexed toLevel,
        uint256 indexed amountMinted,
        uint256 fromLevel,
        uint256 amountBurned,
        uint256 time
    );

    /// @dev Referraladdress managed
    event ReferralAddressManaged(address indexed owner,address indexed referral, uint256 time);

    /// @dev Clear every refund states and withdraw remaining avax
    function withdrawRefunds() external returns(bool);

    /// @dev Increase level of the Avalanche Validator by burning a lower level and minting a higher one (10 lvlx = 1 lvlx+1)
    function upgradeAvalancheValidatorLevel(uint256[] memory _IDs, uint256[] memory _numberOfUpgrades) external returns(bool);

    /// @dev Investor's input to update his activity and his rewards(?rewards)
    function refreshAvalancheValidatorSharesHealth(uint256[] memory _IDs) external returns(bool);
}