// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";
import { LibAvalancheValidatorTokenFacet } from "../libraries/LibAvalancheValidatorTokenFacet.sol";

import { LibContext } from "../../shared/libraries/LibContext.sol";

contract AvalancheValidatorViewTokenFacet is LibContext {
    /**
     * @dev Custom errors
     */
    // Revert if token price is null
    error PricePerTokenIsNull();

    /**
     * VIEW FUNCTIONS
     */
    // Get if Facet is paused
    function getFacetPaused() public view returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.pauseTokenFacet;
    }

    // Get token owner, price, collateral balance, incentives balance and percentage, oracle address and data, and if ERC1155 Availables IDs and related price
    function getTokenInfo(address _token) public view returns(ValidatorStorage.TokenPaymentStruct memory) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.tokenPayment[_token];
    }

    // Calculate Token cost for a specific ERC20 mint
    function getShareCostTokenERC20(address _token, uint256 _amount) public view returns(uint256, bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Cost
        uint256 _shareCost = vs.AV.shareCost;

        /// Price per token TOKEN/AVAX - check how pair is retrived on oracle
        uint256 pricePerToken;
        if (vs.AV.tokenPayment[_token].pricePerToken == 0) { // price oracle
            pricePerToken = vs.AV.oracleTokenPriceFeed[_token];
        } else { // price owner
            pricePerToken = vs.AV.tokenPayment[_token].pricePerToken;
        }
        if (pricePerToken == 0) revert PricePerTokenIsNull();

        uint256 rebatePercentageBPS = vs.AV.tokenPayment[_token].rebatePercentageInBPS;
        uint256 incentivesIterations = LibAvalancheValidatorTokenFacet.getIncentivesIterations(_shareCost, _amount, rebatePercentageBPS, _token);

        uint256 incentives = incentivesIterations * (_shareCost * rebatePercentageBPS / 10_000);

        uint256 tokenAmountToPay = (_shareCost * _amount - incentives) * pricePerToken / 1e18; // T/AVAX -> * || AVAX/T -> /

        bool duable = vs.AV.tokenPayment[_token].avaxDeposited >= (_amount * _shareCost - incentives);

        return (tokenAmountToPay, duable);
    }

    struct VST721C {
        uint256 _shareCost;
        uint256 pricePerToken;
        uint256 _amount;
        uint256 rebatePercentageBPS;
        uint256 incentivesIterations;
        uint256 incentives;
    }
    // Calculate Shares obtained for a specific ERC721 mint
    function getShareMintTokenERC721(address _token, uint256 _amountId) public view returns(uint256, bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        VST721C memory VST721;

        /// Check supply
        require(_amountId > 0, "NO_AMOUNT");

        /// Cost
        VST721._shareCost = vs.AV.shareCost;

        /// Price per token AVAX/TOKEN - check how pair is retrived on oracle
        VST721.pricePerToken;
        if (vs.AV.tokenPayment[_token].pricePerToken == 0) { // price oracle
            VST721.pricePerToken = vs.AV.oracleTokenPriceFeed[_token];
        } else { // price owner
            VST721.pricePerToken = vs.AV.tokenPayment[_token].pricePerToken;
        }
        if (VST721.pricePerToken == 0) revert PricePerTokenIsNull();

        VST721._amount = _amountId * VST721.pricePerToken / VST721._shareCost;

        VST721.rebatePercentageBPS = vs.AV.tokenPayment[_token].rebatePercentageInBPS;
        VST721.incentivesIterations = LibAvalancheValidatorTokenFacet.getIncentivesIterations(VST721._shareCost, VST721._amount, VST721.rebatePercentageBPS, _token);

        VST721.incentives = VST721.incentivesIterations * (VST721._shareCost * VST721.rebatePercentageBPS / 10_000);
        VST721._amount = VST721._amount + (VST721.incentives / VST721._shareCost);

        bool duable = vs.AV.tokenPayment[_token].avaxDeposited >= (VST721._amount * VST721._shareCost - VST721.incentives);

        return (VST721._amount, duable);
    }

    // Get if oracle can update data
    function expiredOracle(address _token) public view returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        if (!LibAvalancheValidatorTokenFacet.isTokenPriceFeed(_token)) return false;
        return (block.timestamp - vs.AV.timestampTokenPriceFeed[_token] >= vs.AV.lastUpdatedTokenPriceFeed[_token]) || vs.AV.updateOnChange[_token];
    }

    // Check if oracle is alllowed
    function isOracleAllowed(address _oracle) public view returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.oracleAllowed[_oracle];
    }

    // Get if oracle price
    function getOraclePrice(address _token) public view returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.oracleTokenPriceFeed[_token];
    }

    // Get token period and last update timestamp
    function getTokenPeriodAndLastTimestampUpdate(address _token) public view returns(uint256, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return (vs.AV.timestampTokenPriceFeed[_token], vs.AV.lastUpdatedTokenPriceFeed[_token]);
    }

    // Fetch which price is currently be used and return it
    function fetchTokenPrice(address _token) public view returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.tokenPayment[_token].pricePerToken == 0 ? vs.AV.oracleTokenPriceFeed[_token] : vs.AV.tokenPayment[_token].pricePerToken;
    }

    // Get all available tokens
    function getAllApprovedTokens() public view returns(address[] memory) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.approvedTokens;
    }

    // Get if token is initialized
    function getNotInitialized(address _token) public view returns(bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.notInitialized[_token];
    }
}