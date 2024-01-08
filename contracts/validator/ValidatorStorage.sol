// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

library ValidatorStorage {
    /// ERC2981 Royalty info
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    /**
     * Token payment struct
     * 
     * Incentives are moslty handled by the partenrship protocol.
     * Shares are sold only if the token owner has deposited enough collateral
     * for people to buy.
     * If not we aren't certain that the owner will fulfill request.
     * QD team can choose to add funds to the position.
     * @notice Incentives can be applied seamingless, meaning that if the protocol decides
     * to add new funds to the psition they could choose to insert a specific price
     * per token that has a negative premium.
     * @notice We still provide the opportunity to add a percentage incentive. This
     * can be applied to both market price and an already predefined token price.
     * If active, any purchase that can't be covered entirely by them the price will
     * shift to the predefined pricePerToken
     * 
     * think about erc1155 implementation
     */
    struct TokenPaymentStruct {
        // Address of the owner with auth over token auth function
        address ownerToken;
        // Price per token, if == 0: market price
        uint256 pricePerToken;

        // Avax deposited to fulfill exchanges
        uint256 avaxDeposited;
        // Avax deposited for incentives
        uint240 avaxIncentives;
        // Rebate percentage BPS
        uint16 rebatePercentageInBPS;

        // fungible
        bool fungible;
        // collection name
        string collectionName;
    }

    /// ERC1155 Avalanche Validator Storage
    struct AvalancheValidator {
        // Next validator completed bool
        bool isNextValidatorCompleted;

        // Mappings for balances and approvals
        mapping(uint256 => mapping(address => uint256)) _balances;
        mapping(address => mapping(address => bool)) _operatorApprovals;
        // Mapping from token ID to name
        string _name;
        // Mapping from token ID to symbol
        string _symbol;

        // Base URI
        string _baseURI;
        // Mapping for token URIs
        mapping(uint256 => string) _tokenURIs;

        // Royalties
        RoyaltyInfo _defaultRoyaltyInfo;
        // Mapping from token ID to Royalties
        mapping(uint256 => RoyaltyInfo) _tokenRoyaltyInfo;

        // Validator semi fungible tokens IDs - SFT
        uint256 AVALANCHE_VALIDATOR_LVL1;
        uint256 AVALANCHE_VALIDATOR_LVL2;
        uint256 AVALANCHE_VALIDATOR_LVL3;
        uint256 AVALANCHE_VALIDATOR_LVL4;
        uint256 AVALANCHE_VALIDATOR_LVL5;
        
        // SFT's max supply, mapping from tokens IDs to max supply
        mapping(uint256 => uint256) AVALANCHE_VALIDATOR_MAX_SUPPLY; // 30'000'000 - 2'571'000 - 207'600 - 15'030 - 828 
        // SFT's current supply, mapping from tokens IDs to current supply
        mapping(uint256 => uint256) AVALANCHE_VALIDATOR_CURRENT_SUPPLY; // <= MAX_SUPPLY := 4'290'000 at 0.1 - 495'000 at 1 - 57'300 at 10 - 6'750 at 100 - 828 at 1'000
        // SFT's current cooling supply, mapping from tokens IDs to current cooling supply
        mapping(uint256 => uint256) AVALANCHE_VALIDATOR_CURRENT_COOLING_SUPPLY;
        
        // Period you need to be active
        uint256 activityPeriod;

        // Period between validator activations
        uint256 coolingPeriod;
        uint256 coolingPeriodStart;
        uint256 rewardCoolingPeriod; // cancel?

        // Cost of a single LVL1 share
        uint256 shareCost;

        // Pause Token Facet functions
        bool pauseTokenFacet;
        // Token payment, mapping from token address to struct
        mapping(address => TokenPaymentStruct) tokenPayment;
        // mapping(address => mapping(uint256 => TokenPaymentStruct)) tokenPaymentERC1155;
        address[] approvedTokens;
        mapping(address => uint256) approvedTokensIndex;
        mapping(address => bool) notInitialized;
        // Oracle feeds mapping from token address to feed
        mapping(address => uint256) oracleTokenPriceFeed;
        // mapping(address => mapping(uint256 => uint256)) oracleTokenPriceFeedERC1155;
        // Last timestamp of update of the feed
        mapping(address => uint256) timestampTokenPriceFeed;
        mapping(address => uint256) lastUpdatedTokenPriceFeed;
        mapping(address => bool) updateOnChange;
        // Oracle addresses allowed and counter
        mapping(address => bool) oracleAllowed;
        mapping(address => uint256) oracleIndex;
        address[] oracles;

        // QuarryDraw fee
        uint256 QDValidatorFee;
        uint256 QDLiquidStakingFee;

        // Percentage proportion - default: BPS
        uint256 percentageProportion;

        // Validator deposit
        uint256 avaxToStake;

        // Incentives
        bool avaxIncentivesActive;
        uint256 avaxIncentives;
        uint256 rebatePercentageInBPS;
        uint256 numberOfRebates;

        // Rewards
        mapping(uint256 => uint256) avaxRewardPerLevel;
        uint256 QDrewardFee;
        uint256 duration;
        uint256 finishAt;
        mapping(uint256 => uint256) updatedAt; // from token ID to last updated time - updatedAt
        mapping(uint256 => uint256) rewardRate; // from token ID to rewards rate amount / coolingPeriod
        mapping(uint256 => uint256) rewardPerTokenStored; // from token ID to rewards per token stored
        mapping(uint256 => mapping(address => uint256)) userRewardPerTokenPaid; // from token ID to user reward per token paid
        mapping(uint256 => mapping(address => uint256)) rewards; // from token ID to rewards

        // Funds to be redeemed
        bool redeemsActive;
        uint256 avaxToRedeem;
        uint256 refundsPercentage;
        uint256 managerRefundsPercentage;
        uint256 refundsAmount;
        bytes32 merkletreeRefunds;
        uint256 redeemTime;
        mapping(uint256 => mapping(address => bool)) redeemed;

        // Mapping from token ID to address to health
        mapping(uint256 => mapping(address => uint256)) health;
        // Bool to confirm owner is holding
        mapping(uint256 => mapping(address => bool)) holder;

        // Mapping from user address to user referred address
        mapping(address => address) referredAddress;
        // Mapping from user address to number of referral
        mapping(address => uint256) referralNumber;
        // Mapping from referralNumber to percentage rewards referral
        mapping(uint256 => uint256) referralRewards;
    }

    /// Mapping from every validator to validator storage
    struct ValidatorStorageStruct {
        // Mapping from validator number to AvalancheValidator struct
        AvalancheValidator AV;
    }

    // Storage pointer
    bytes32 internal constant VALIDATORSTORAGE_SLOT = keccak256('contracts.validator.libraries.LibValidatorStorage');

    // Returns storage slot
    function validatorStorage() internal pure returns(ValidatorStorageStruct storage vs) {
        bytes32 slot = VALIDATORSTORAGE_SLOT;
        assembly {
            vs.slot := slot
        }
    }

    // Return token owner address
    function tokenOwner(address _token) internal view returns(address) {
         ValidatorStorageStruct storage vs = validatorStorage();
         return vs.AV.tokenPayment[_token].ownerToken;
    }

    // Return oracle allowed
    function allowedOracle(address _oracle) internal view returns(bool) {
         ValidatorStorageStruct storage vs = validatorStorage();
         return vs.AV.oracleAllowed[_oracle];
    }
}