// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";

import { LibAvalancheValidatorDepositFacet } from "../libraries/LibAvalancheValidatorDepositFacet.sol";
import { LibAvalancheValidatorTokenFacet } from "../libraries/LibAvalancheValidatorTokenFacet.sol";
import { LibERC1155Facet } from "../libraries/LibERC1155Facet.sol";

import { LibDiamond } from "../../shared/libraries/LibDiamond.sol";
import { LibReentrancyGuard } from "../../shared/libraries/LibReentrancyGuard.sol";
import { LibAddress } from "../../shared/libraries/LibAddress.sol";
import { LibContext } from "../../shared/libraries/LibContext.sol";
import { IERC20 } from "../../shared/interfaces/IERC20.sol";
import { IERC721 } from "../../shared/interfaces/IERC721.sol";

contract AvalancheValidatorTokenFacet is LibContext, LibReentrancyGuard {
    /**
     * @dev Custom errors
     */
    // Revert if token price is null
    error PricePerTokenIsNull();
    // Revert if oracle is not allowed to update
    error UpdateNotPossible();
    // Revert if market price has no update
    error CannotSetMaretPriceWithoutOracleTimestamp();

    /**
     * @dev Events
     */
    /// @dev Emitted when Avalanche validator's share sold event occours
    event avalancheValidatorShareSold(address indexed costumer, uint256 amount, uint256 time);
    /// @dev Emitted when a new token is added or removed
    event Token(bool indexed created, address indexed token);
    /// @dev Emitted when token is managed
    event TokenManaged(address indexed token, uint256 indexed price, uint256 oracleTimestamp, bool _fungible, string data);
    /// @dev Emitted when toen price is updated
    event TokenFeedUpdated(uint256 time, uint256 price);

    /**
     * @dev Pause Token functions
     */
    function pauseTokenFacet(bool pause) external returns(bool) {
        LibDiamond.enforceIsContractOwner();
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        vs.AV.pauseTokenFacet = pause;
        return true;
    }

    /**
     * @dev Oracle feed
     */
    function updateOracleFeed(address _token, uint256 _value) external returns(bool) {
        LibAvalancheValidatorTokenFacet.isTokenFacetPaused();

        LibAvalancheValidatorTokenFacet.forceTokenExist(_token);
        LibAvalancheValidatorTokenFacet.forceTokenPriceFeed(_token);
        LibAvalancheValidatorTokenFacet.forceOracleAllowed(_msgSender());
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        // Check update credentials
        bool _updateOnChange = vs.AV.updateOnChange[_token];
        uint256 _timestampTokenPriceFeed = vs.AV.timestampTokenPriceFeed[_token];
        uint256 _lastUpdatedTokenPriceFeed = vs.AV.lastUpdatedTokenPriceFeed[_token];

        if (!(block.timestamp - _timestampTokenPriceFeed >= _lastUpdatedTokenPriceFeed || _updateOnChange)) revert UpdateNotPossible();

        // Update feed credentials
        if (_updateOnChange) {
            delete vs.AV.updateOnChange[_token];
        }
        if (block.timestamp - _timestampTokenPriceFeed >= _lastUpdatedTokenPriceFeed) {
            vs.AV.lastUpdatedTokenPriceFeed[_token] = block.timestamp;
        }

        // Update feed
        vs.AV.oracleTokenPriceFeed[_token] = _value;

        // Event
        emit TokenFeedUpdated(block.timestamp, _value);

        // Success
        return true;
    }
    function addOracleAddress(address _oracle) external returns(bool) {
        LibAvalancheValidatorTokenFacet.isTokenFacetPaused();

        LibDiamond.enforceIsContractOwner();
        LibAvalancheValidatorTokenFacet.forceOracleUnexist(_oracle);

        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        vs.AV.oracleAllowed[_oracle] = true;
        vs.AV.oracleIndex[_oracle] = vs.AV.oracles.length;
        vs.AV.oracles.push(_oracle);
        
        return true;
    }
    function removeOracleAddress(address _oracle) external returns(bool) {
        LibAvalancheValidatorTokenFacet.isTokenFacetPaused();

        LibDiamond.enforceIsContractOwner();
        LibAvalancheValidatorTokenFacet.forceOracleExist(_oracle);
        
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        delete vs.AV.oracleAllowed[_oracle];
        vs.AV.oracleIndex[vs.AV.oracles[vs.AV.oracles.length - 1]] = vs.AV.oracleIndex[_oracle];
        vs.AV.oracles[vs.AV.oracleIndex[_oracle]] = vs.AV.oracles[vs.AV.oracles.length - 1];
        delete vs.AV.oracleIndex[_oracle];
        vs.AV.oracles.pop();

        return true;
    }

    /**
     * @dev Manage tokens
     */
    function createNewToken(address _owner, address _token) external returns(bool) {
        LibAvalancheValidatorTokenFacet.isTokenFacetPaused();

        LibDiamond.enforceIsContractOwner();
        LibAvalancheValidatorTokenFacet.forceTokenUnexist(_token);

        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        vs.AV.approvedTokensIndex[_token] = vs.AV.approvedTokens.length;
        vs.AV.approvedTokens.push(_token);
        vs.AV.tokenPayment[_token].ownerToken = _owner;

        vs.AV.notInitialized[_token] = true;

        emit Token(true, _token);

        return true;
    }
    function removeExistingToken(address _token) external returns(bool) {
        LibAvalancheValidatorTokenFacet.isTokenFacetPaused();

        LibDiamond.enforceIsContractOwner();
        LibAvalancheValidatorTokenFacet.forceTokenExist(_token);

        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        uint256 remainingDeposit = vs.AV.tokenPayment[_token].avaxDeposited + uint256(vs.AV.tokenPayment[_token].avaxIncentives);
        (bool success, ) = vs.AV.tokenPayment[_token].ownerToken.call{value:remainingDeposit}("");
        require(success, "Transfer failed.");

        vs.AV.approvedTokensIndex[vs.AV.approvedTokens[vs.AV.approvedTokens.length - 1]] = vs.AV.approvedTokensIndex[_token];
        vs.AV.approvedTokens[vs.AV.approvedTokensIndex[_token]] = vs.AV.approvedTokens[vs.AV.approvedTokens.length - 1];
        vs.AV.approvedTokens.pop();
        delete vs.AV.tokenPayment[_token];
        delete vs.AV.timestampTokenPriceFeed[_token];
        delete vs.AV.oracleTokenPriceFeed[_token];
        delete vs.AV.timestampTokenPriceFeed[_token];
        delete vs.AV.lastUpdatedTokenPriceFeed[_token];
        delete vs.AV.updateOnChange[_token];
        delete vs.AV.notInitialized[_token];

        emit Token(false, _token);

        return true;
    }

    /**
     * @dev Manage token collateral or change token price, or execute both - Owner
     * @param _token address of the token's contract
     * @param _pricePerToken_InTokenOverAvaxERC20_InAvaxOverTokenERC721_InWei needs to have different approaches based on token fungibility.
     * If it is fungible the price has to be setted as TOKEN/AVAX, instead if it is unfungible the price has to be setted as AVAX/TOKEN,
     * this way we can align with the underlaying asset exchange logic. If you don't want to update it pass in the current value.
     * @param _newCollateralInWEI new collateral in wei for the OTC exchange
     * @param _newCollateralIncentivesInWEI new collateral in wei for the OTC exchange's incentives
     * @param _rebatePercentageInBPS percentage of rebate off incentivized toens in BPS, if you don't want to update the current
     * value pass that value in.
     * @param _updateTimestampOracle used to update desired frequency of oracle updates, use the current _updateTimestampOracle value
     * if you don't want to change it.
     * @param _fungible bool representing fungibility of the token. Currently necessary for the oracle.
     * @param data used to update collection name, use empty string ("") to mantain current value.
     */
    function ownerManageToken(
        address _token,
        uint256 _pricePerToken_InTokenOverAvaxERC20_InAvaxOverTokenERC721_InWei,
        uint256 _newCollateralInWEI,
        uint240 _newCollateralIncentivesInWEI,
        uint16 _rebatePercentageInBPS,
        uint256 _updateTimestampOracle,
        bool _fungible,
        string calldata data
        ) external payable returns(bool) {
        LibAvalancheValidatorTokenFacet.isTokenFacetPaused();

        LibAvalancheValidatorTokenFacet.forceTokenOwner(_token);
        LibAvalancheValidatorTokenFacet.forceTokenExist(_token);

        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        if (vs.AV.notInitialized[_token] == true) vs.AV.notInitialized[_token] = false;

        require(_rebatePercentageInBPS <= 10_000, "WRONG_PERCENTAGE");
        require(msg.value >= _newCollateralInWEI + _newCollateralIncentivesInWEI, "WRONG_DEPOSIT");

        if (vs.AV.tokenPayment[_token].pricePerToken != _pricePerToken_InTokenOverAvaxERC20_InAvaxOverTokenERC721_InWei) {
            vs.AV.tokenPayment[_token].pricePerToken = _pricePerToken_InTokenOverAvaxERC20_InAvaxOverTokenERC721_InWei;
        }

        vs.AV.tokenPayment[_token].avaxDeposited += _newCollateralInWEI;
        vs.AV.tokenPayment[_token].avaxIncentives += _newCollateralIncentivesInWEI;

        if (vs.AV.tokenPayment[_token].rebatePercentageInBPS != _rebatePercentageInBPS) {
            vs.AV.tokenPayment[_token].rebatePercentageInBPS = _rebatePercentageInBPS;
        }

        if (vs.AV.tokenPayment[_token].pricePerToken == 0) {
            vs.AV.updateOnChange[_token] = true;
            if (vs.AV.timestampTokenPriceFeed[_token] != _updateTimestampOracle) {
                vs.AV.timestampTokenPriceFeed[_token] = _updateTimestampOracle;
            }
        } else if (vs.AV.timestampTokenPriceFeed[_token] != 0 && vs.AV.tokenPayment[_token].pricePerToken == 0) {
            vs.AV.timestampTokenPriceFeed[_token] = 0;
        } else if (vs.AV.timestampTokenPriceFeed[_token] == 0 && vs.AV.tokenPayment[_token].pricePerToken == 0) {
            revert CannotSetMaretPriceWithoutOracleTimestamp();
        }

        if (vs.AV.tokenPayment[_token].fungible != _fungible) {
            vs.AV.tokenPayment[_token].fungible = _fungible;
        }
        if (keccak256(abi.encodePacked((data))) != keccak256(abi.encodePacked(("")))) {
            vs.AV.tokenPayment[_token].collectionName = data;
        }

        emit TokenManaged(_token, vs.AV.tokenPayment[_token].pricePerToken, _updateTimestampOracle, _fungible, data);

        return true;
    }
    /**
     * @dev Manage token collateral - QuarryDraw
     * params have the same meaning as {ownerManageToken} params.
     */
    function quarryDrawManageToken(
        address _token,
        uint256 _newCollateralInWEI,
        uint240 _newCollateralIncentivesInWEI,
        uint16 _rebatePercentageInBPS, 
        uint256 _updateTimestampOracle,
        bool _fungible,
        string calldata data
        ) external payable returns(bool) {
        LibAvalancheValidatorTokenFacet.isTokenFacetPaused();

        LibDiamond.enforceIsContractOwner();
        LibAvalancheValidatorTokenFacet.forceTokenExist(_token);

        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        if (vs.AV.notInitialized[_token] == true) vs.AV.notInitialized[_token] = false;

        require(_rebatePercentageInBPS <= 10_000, "WRONG_PERCENTAGE");
        require(msg.value >= _newCollateralInWEI + _newCollateralIncentivesInWEI, "WRONG_DEPOSIT");

        vs.AV.tokenPayment[_token].avaxDeposited += _newCollateralInWEI;
        vs.AV.tokenPayment[_token].avaxIncentives += _newCollateralIncentivesInWEI;

        if (vs.AV.tokenPayment[_token].rebatePercentageInBPS != _rebatePercentageInBPS) {
            vs.AV.tokenPayment[_token].rebatePercentageInBPS = _rebatePercentageInBPS;
        }

        if (vs.AV.tokenPayment[_token].pricePerToken == 0) {
            vs.AV.updateOnChange[_token] = true;
            if (vs.AV.timestampTokenPriceFeed[_token] != _updateTimestampOracle) {
                vs.AV.timestampTokenPriceFeed[_token] = _updateTimestampOracle;
            }
        } else if (vs.AV.timestampTokenPriceFeed[_token] != 0 && vs.AV.tokenPayment[_token].pricePerToken != 0) {
            vs.AV.timestampTokenPriceFeed[_token] = 0;
            _updateTimestampOracle = 0;
        } else if (vs.AV.timestampTokenPriceFeed[_token] == 0 && vs.AV.tokenPayment[_token].pricePerToken == 0) {
            revert CannotSetMaretPriceWithoutOracleTimestamp();
        }

        if (vs.AV.tokenPayment[_token].fungible != _fungible) {
            vs.AV.tokenPayment[_token].fungible = _fungible;
        }
        if (keccak256(abi.encodePacked((data))) != keccak256(abi.encodePacked(("")))) {
            vs.AV.tokenPayment[_token].collectionName = data;
        }

        emit TokenManaged(_token, vs.AV.tokenPayment[_token].pricePerToken, _updateTimestampOracle, _fungible, data);

        return true;
    }

    /**
     * @dev Mint an Avalanche Validator level 1 share from contract with ERC20 token
     * @param _amount of shares to mint
     */
    function mintAvalancheValidatorShareTokenERC20(address _token, uint256 _amount) external payable nonReentrant returns(bool) {
        LibAvalancheValidatorTokenFacet.isTokenFacetPaused();

        LibAvalancheValidatorTokenFacet.forceTokenExist(_token);
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        /// Check supply
        require(vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[0] + _amount <= vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[0], "Max supply reached");
        require(_amount > 0, "NO_AMOUNT");

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

        /// Deposit tokens
        IERC20(_token).transferFrom(_msgSender(), vs.AV.tokenPayment[_token].ownerToken, tokenAmountToPay);

        /// Deposit payment
        vs.AV.tokenPayment[_token].avaxIncentives -= uint240(incentives);
        require(vs.AV.tokenPayment[_token].avaxDeposited >= (_amount * _shareCost - incentives), "INSUFICIENT_FUNDS");
        vs.AV.tokenPayment[_token].avaxDeposited -= (_amount * _shareCost ) - incentives;
        vs.AV.avaxToStake += _amount * _shareCost;

        /// Update supply
        vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[0] += _amount;

        /// Check Quarry Draw fee
        LibAvalancheValidatorDepositFacet.checkQDValidatorFee();

        /// Check and update health
        require(LibAvalancheValidatorDepositFacet.setLVL1MinterHealth(_msgSender(), block.timestamp, _amount), "Health not setted correctly");

        /// Mint shares
        LibERC1155Facet._mint(_msgSender(), 0, _amount, "0x");

        /// Event
        emit avalancheValidatorShareSold(_msgSender(), _amount, block.timestamp);

        /// Success
        return true;
    }
    struct VST721C {
        uint256 _shareCost;
        uint256 pricePerToken;
        uint256 _amount;
        uint256 rebatePercentageBPS;
        uint256 incentivesIterations;
        uint256 incentives;
    }
    /**
     * @dev Mint an Avalanche Validator level 1 share from contract with ERC721 token. Based on token
     * exchanged, thus _ids length, mint shares.
     * @param _token token address
     * @param _ids token ids
     */
    function mintAvalancheValidatorShareTokenERC721(address _token, uint256[] memory _ids) external payable nonReentrant returns(bool) {
        LibAvalancheValidatorTokenFacet.isTokenFacetPaused();

        LibAvalancheValidatorTokenFacet.forceTokenExist(_token);
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        VST721C memory VST721;

        /// Check supply
        require(_ids.length > 0, "NO_AMOUNT");

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

        VST721._amount = _ids.length * VST721.pricePerToken / VST721._shareCost;
        require(vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[0] + VST721._amount <= vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[0], "Max supply reached");

        VST721.rebatePercentageBPS = vs.AV.tokenPayment[_token].rebatePercentageInBPS;
        VST721.incentivesIterations = LibAvalancheValidatorTokenFacet.getIncentivesIterations(VST721._shareCost, VST721._amount, VST721.rebatePercentageBPS, _token);

        VST721.incentives = VST721.incentivesIterations * (VST721._shareCost * VST721.rebatePercentageBPS / 10_000);
        // uint256 incentivesAmount = incentives / _shareCost;
        VST721._amount = VST721._amount + (VST721.incentives / VST721._shareCost);

        /// Deposit tokens
        for (uint256 i = 0; i < _ids.length; ) {
            IERC721(_token).safeTransferFrom(_msgSender(), vs.AV.tokenPayment[_token].ownerToken, _ids[i]);
            unchecked {
                ++i;
            }
        }

        /// Deposit payment
        vs.AV.tokenPayment[_token].avaxIncentives -= uint240((VST721.incentives / VST721._shareCost) * VST721._shareCost);
        require(vs.AV.tokenPayment[_token].avaxDeposited >= (VST721._amount * VST721._shareCost - VST721.incentives), "INSUFFICIENT_FUNDS");
        vs.AV.tokenPayment[_token].avaxDeposited -= (VST721._amount * VST721._shareCost - (VST721.incentives / VST721._shareCost) * VST721._shareCost);
        vs.AV.avaxToStake += VST721._amount * VST721._shareCost;

        /// Update supply
        vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[0] += VST721._amount;

        /// Check Quarry Draw fee
        LibAvalancheValidatorDepositFacet.checkQDValidatorFee();

        /// Check and update health
        require(LibAvalancheValidatorDepositFacet.setLVL1MinterHealth(_msgSender(), block.timestamp, VST721._amount), "Health not setted correctly");

        /// Mint shares
        LibERC1155Facet._mint(_msgSender(), 0, VST721._amount, "0x");

        /// Event
        emit avalancheValidatorShareSold(_msgSender(), VST721._amount, block.timestamp);

        /// Success
        return true;
    }
}