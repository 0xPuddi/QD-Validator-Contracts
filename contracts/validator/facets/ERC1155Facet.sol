// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { ValidatorStorage } from "../ValidatorStorage.sol";

import { IERC1155 } from "../../shared/interfaces/IERC1155.sol";
import { IERC1155MetadataURI } from "../../shared/interfaces/IERC1155MetadataURI.sol";
import { IERC2981 } from "../../shared/interfaces/IERC2981.sol";

import { LibAddress } from "../../shared/libraries/LibAddress.sol";
import { LibContext } from "../../shared/libraries/LibContext.sol";
import { LibStrings } from "../../shared/libraries/LibStrings.sol";
import { LibERC1155Facet } from "../libraries/LibERC1155Facet.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155Facet is LibContext, IERC2981, IERC1155, IERC1155MetadataURI {
    using LibAddress for address;
    using LibStrings for uint256;

    /**
     * @dev Name of the whole contract
     */
    function name() public view virtual returns (string memory) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV._name;
    }

    /**
     * @dev Symbol of the wholw contract
     */
    function symbol() public view virtual returns (string memory) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV._symbol;
    }

    /**
     * @dev Total current amount of tokens in with a given id.
     */
    function currentSupply(uint256 id) public view virtual returns(uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.AVALANCHE_VALIDATOR_CURRENT_SUPPLY[id];
    }

    /**
     * @dev Max amount of tokens in with a given id.
     */
    function maxSupply(uint256 id) public view virtual returns (uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[id];
    }

    /**
     * @dev Indicates whether any token exist in circulation with a given id, or not.
     */
    function existsInCirculation(uint256 id) public view virtual returns (bool) {
        return currentSupply(id) > 0;
    }

    /**
     * @dev Indicates whether any token exist in the contract with a given id, or not.
     */
    function exists(uint256 id) public view virtual returns (bool) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();
        return vs.AV.AVALANCHE_VALIDATOR_MAX_SUPPLY[id] > 0;
    }

    /**
     * @dev IERC2981 {royaltyInfo} implementation
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view virtual override returns (address, uint256) {
        ValidatorStorage.ValidatorStorageStruct storage vs = ValidatorStorage.validatorStorage();

        ValidatorStorage.RoyaltyInfo memory royalty = vs.AV._tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = vs.AV._defaultRoyaltyInfo;
        }

        return (royalty.receiver, (_salePrice * royalty.royaltyFraction) / LibERC1155Facet._feeDenominator());
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the concatenation of the `_baseURI`
     * and the token-specific uri if the latter is set
     *
     * This enables the following behaviors:
     *
     * - if `_tokenURIs[tokenId]` is set, then the result is the concatenation
     *   of `_baseURI` and `_tokenURIs[tokenId]` (keep in mind that `_baseURI`
     *   is empty per default);
     *
     * - if `_tokenURIs[tokenId]` is NOT set then we fallback to `uri()`
     *   which in most cases will contain `ERC1155._uri`;
     *
     * - if `_tokenURIs[tokenId]` is NOT set, and if the parents do not have a
     *   uri value set, then the result is empty.
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return LibERC1155Facet.internalUri(tokenId);
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        return LibERC1155Facet.internalBalanceOf(account, id);
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
            unchecked {
                ++i;
            }
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        LibERC1155Facet._setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return LibERC1155Facet.internalIsApprovedForAll(account, operator);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        LibERC1155Facet._safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        LibERC1155Facet._safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}