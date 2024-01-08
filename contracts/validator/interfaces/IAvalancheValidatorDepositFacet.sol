// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Avalanche first deposit validator interface
 */
interface IAvalancheValidatorDepositFacet {
    /// @dev Validator funds deposited event
    event validatorFundsDeposited(uint256 indexed value, address sender, uint256 time);

    /// @dev Liquid staking funds deposited event
    event liquidStakingFundsDeposited(uint256 indexed value, address sender, uint256 time);

    /// @dev Trace incentivess deposited
    event incentivesDeposited(uint256 indexed rebatePercentage, uint256 indexed _numberOfRebates, address sender, uint256 time);

    /// @dev Avalanche validator's share sold event
    event avalancheValidatorShareSold(address indexed costumer, uint256 amount, uint256 time);

    /// @dev Deposit of refunds event
    event refundsDeposited(uint256[5] indexed amount, uint256 value, uint256 time);

    /// @dev emit at shares burned
    event sharesBurned(address indexed burner, uint256[] ids, uint256[] amounts);

    /// @dev Mint an Avalanche Validator level 1 share from contract
    function mintAvalancheValidatorShareAVAX(uint256 _amount, bytes memory _data) external payable returns(bool);

    /// @dev Deposit rewards from validation and liquid stakig, then distribute it between levels and QD
    function depositRewards(uint256 _liquidStakigRewards, uint256[] memory _ids) external payable returns(bool);

    /// @dev Add incentives to mint shares
    function depositIncentives(uint256 _rebatePercentage, uint256 _numberOfRebates) external payable returns(bool);

    /// @dev Deposit funds for refund at 80% of their initial value
    function depositRefunds(uint256[5] memory _amount, uint256[5] memory _IDs, bytes32 _merkletree, uint256 _redeemTimeInSeconds) external payable returns(bool);

    /// @dev Burn share
    function burnShares(uint256[] memory ids, uint256[] memory amounts) external returns(bool);
}