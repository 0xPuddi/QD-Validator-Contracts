// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";

/**
 * Avalanche Validator Thor facet library.
 */
library LibAvalancheValidatorTokenFacet {
    /**
     * @dev Get the most incentives iterations possible
     */
    function getIncentivesIterations(uint256 _shareCost, uint256 _amount, uint256 rebatePercentageBPS, address _token) internal view returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        uint256 avaxIncentives = vs.AV.tokenPayment[_token].avaxIncentives;
        uint256 incentivesIterations = 0;

        for (uint256 i = 0; i <= _amount; ) {
            if ((_shareCost * rebatePercentageBPS / 10_000) * i <= avaxIncentives) {
                incentivesIterations = i;
            } else {
                break;
            }
            unchecked {
                ++i;
            }
        }

        return incentivesIterations;
    }

    // Force sender to be token owner
    function forceTokenOwner(address _token) internal view {
        require(msg.sender == ValidatorStorage.tokenOwner(_token), "NOT_TOKEN_OWNER");
    }

    // Force oracle to be allowed
    function forceOracleAllowed(address _oracle) internal view {
        require(ValidatorStorage.allowedOracle(_oracle), "ORACLE_NOT_ALLOWED");
    }

    // Force token to exist
    function forceTokenExist(address _token) internal view {
        require(ValidatorStorage.tokenOwner(_token) != address(0), "TOKEN_DOESNT_EXIST");
    }
    function forceTokenUnexist(address _token) internal view {
        require(ValidatorStorage.tokenOwner(_token) == address(0), "TOKEN_ALREADY_EXISTS");
    }

    // Force oracle to exist
    function forceOracleExist(address _oracle) internal view {
        require(ValidatorStorage.allowedOracle(_oracle), "ORACLE_DOESNT_EXIST");
    }
    function forceOracleUnexist(address _oracle) internal view {
        require(!ValidatorStorage.allowedOracle(_oracle), "ORACLE_ALREADY_EXISTS");
    }

    // Facet paused checker
    function isTokenFacetPaused() internal view {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        require(!vs.AV.pauseTokenFacet, "TOKEN_FACET_PAUSED");
    }

    // Force token to have a price feed
    function forceTokenPriceFeed(address _token) internal view {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        require(vs.AV.timestampTokenPriceFeed[_token] != 0, "TOKEN_NOT_ON_FEED");
    }
    function isTokenPriceFeed(address _token) internal view returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.timestampTokenPriceFeed[_token] != 0;
    }
}