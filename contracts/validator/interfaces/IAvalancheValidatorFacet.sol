// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Avalanche first validator interface
 */
interface IAvalancheValidatorFacet {    
    /// @dev Refunds redeemed event
    event refundsRedeemed(address indexed redeemer, uint256 amount, uint256 value, uint256 time);

    /// @dev Refunds managed event
    event refundsManaged(address indexed redeemer, uint256 amount, uint256 value, uint256 time);

    /// @dev Trace avax withdrawn that go to the validator
    event avaxWithdrawnToStake(uint256 indexed amount, address manager, uint256 time);
    
    /// @dev Trace incentives withdrawn
    event incentivesStoppedAndWithdrawn(uint256 indexed amount, address manager, uint256 time);

    /// @dev Event emitted when inactive shares are manager
    event inactiveShareManaged(address indexed manager, uint256 indexed id, uint256 time);

    /// @dev collect shares rewards
    function collectRewards(uint256[] memory _ids) external returns(bool);

    /// @dev Redeem refund function 
    function redeemRefund(uint256 _amountRedeemed, uint256 _id, bytes32[] calldata _merkleProof) external returns(bool);

    /// @dev Funds that have not been redeemed
    function manageUnclaimedRefunds(address _refundsUnclaimer, uint256 _amount, uint256 _id, bytes32[] calldata _merkleProof) external returns(bool);

    /// @dev Give people permission to burn inactive validator shares and claim his rewards - bot protection? add only nft holders able add freez time? proportional to holding?
    function manageInactiveValidatorShares(address _inactiveOwner, uint256 _id) external returns(bool);

    /// @dev Withdraw QuarryDraw reward fee
    function withdrawQuarryDrawRewardFee() external returns(bool);

    /// @dev Withdraw $AVAX to stake it into the validator
    function withdrawAvaxToStake() external returns(bool);

    /// @dev Withdraw incentives 
    function withdrawIncentives() external returns(bool);
}