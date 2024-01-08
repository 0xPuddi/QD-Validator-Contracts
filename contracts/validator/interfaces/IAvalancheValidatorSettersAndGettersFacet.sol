// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Avalanche first validator setters interface
 */
interface IAvalancheValidatorSettersAndGettersFacet {
    /// @dev Setted new activity period manually event
    event settedActivityPeriod(uint256 indexed timeInSecond, uint256 time);

    /// @dev Setted new share cost manually event
    event settedShareCost(uint256 indexed costInWei, uint256 time);

    /// @dev Setted new default royalty manually event
    event settedDefaultRoyalty(address indexed receiver, uint96 feeNumerator);

    /// @dev Setted new cooling period manualy event
    event settedCoolingPeriod(uint256 coolingPeriodInSecond, uint256 coolingPeriodStartInSecond);

    /// @dev Setted new refunds percentage
    event settedRefundsAndRefundsManagerPercentage(uint256 indexed _newRefundsPercentageInBPS, uint256 indexed _newRefundsManagerPercentageInBPS, uint256 time);

    /// @dev Next validator has been completed
    event settedNextValidatorIsCompleted(address _receiver, uint256 indexed time);

    /// @dev Set activityPeriod
    function setActivityPeriodManual(uint256 _timeInSecond) external returns(bool);

    /// @dev Set shareCost
    function setShareCostManual(uint256 _costInWei) external returns(bool);

    /// @dev Set _defaultRoialtyInfo
    function setDefaultRoyaltyManual(address receiver, uint96 feeNumeratorInBPS) external returns(bool);

    /// @dev Set coolingPeriod
    function setCoolingPeriodManual(uint256 _coolingPeriodInSecond) external returns(bool);

    /// @dev Set a new refunds percentage
    function setRefundsAndRefundsManagerPercentageManual(uint256 _newRefundsPercentageInBPS, uint256 _newRefundsManagerPercentageInBPS) external returns(bool);

    /// @dev Adjust fees on next validator complete
    function setNextValidatorCompletedManual(address _receiver) external returns(bool);
}

