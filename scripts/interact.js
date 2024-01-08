require("dotenv").config();

const ethers = require('ethers');

let provider = new ethers.providers.JsonRpcProvider('https://api.avax-test.network/ext/bc/C/rpc');
let signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

let addressERC20 = "0x7eD9861A37d5Ef8a63e5f4fAe8AC2af7e65915bd";
const ABIERC20 = require("../artifacts/contracts/testingContracts/ERC20.sol/ERC20.json");
let ERC20 = (new ethers.Contract(addressERC20, ABIERC20.abi, provider)).connect(signer);

let addressERC721 = "0xcc761512c98BB06dF3e891F14E28B60a0E98008c";
const ABIERC721 = require("../artifacts/contracts/testingContracts/ERC721.sol/ERC721.json");
let ERC721 = (new ethers.Contract(addressERC721, ABIERC721.abi, provider)).connect(signer);

let diamondAddress = "0x5A6Ff6AAfbDE4f883b55eFbDDE78Ff6ad377f06e";
const ABITokenFacet = require('../artifacts/contracts/validator/facets/AvalancheValidatorTokenFacet.sol/AvalancheValidatorTokenFacet.json');
const ABIViewTokenFacet = require('../artifacts/contracts/validator/facets/AvalancheValidatorViewTokenFacet.sol/AvalancheValidatorViewTokenFacet.json');
let TokenFacet = (new ethers.Contract(diamondAddress, ABITokenFacet.abi, provider)).connect(signer);
let ViewTokenFacet = (new ethers.Contract(diamondAddress, ABIViewTokenFacet.abi, provider)).connect(signer);
const ABIAvalancheValidatorFacet = require('../artifacts/contracts/validator/facets/AvalancheValidatorFacet.sol/AvalancheValidatorFacet.json');
let AvalancheValidatorFacet = (new ethers.Contract(diamondAddress, ABIAvalancheValidatorFacet.abi, provider)).connect(signer);

let readableABI = [
    "function getShareCostTokenERC20(address _token, uint256 _amount) public view returns(uint256, bool)"
]
let ReadableTokenFacet = (new ethers.Contract(diamondAddress, readableABI, provider)).connect(signer);

let tx;
let response;
// Interaction functions
async function main() {
    // tx = await ERC20.mint(signer.address, ethers.utils.parseEther('10'));
    // await tx.wait(1);
    // for (let i = 0; i < 10; i++) {
    //     tx = await ERC721.mint(signer.address, i);
    //     await tx.wait(1);
    // }, {gasLimit: 300_000}

    // tx = await TokenFacet.createNewToken(signer.address, addressERC20);
    // response = await tx.wait(1);
    // tx = await TokenFacet.createNewToken(signer.address, addressERC721);
    // response = await tx.wait(1);

    // tx = await TokenFacet.removeExistingToken(addressERC20);
    // response = await tx.wait(1);
    // tx = await TokenFacet.removeExistingToken(addressERC721);
    // response = await tx.wait(1);

    // tx = await TokenFacet.addOracleAddress(signer.address);
    // response = await tx.wait(1);

    // tx = await TokenFacet.ownerManageToken(addressERC20, 0, ethers.utils.parseEther('0.2'), ethers.utils.parseEther('0.3'), 2500, 10, true, "ThorFi-Token", {value: ethers.utils.parseEther('0.5')});
    // response = await tx.wait(1);
    // tx = await TokenFacet.ownerManageToken(addressERC721, 0, ethers.utils.parseEther('1'), 0, 0, 10, false, "odin-origin", {value: ethers.utils.parseEther('1')});
    // response = await tx.wait(1);

    // tx = await ERC20.approve(diamondAddress, ethers.utils.parseEther('10'));
    // await tx.wait(1);
    // tx = await TokenFacet.mintAvalancheValidatorShareTokenERC20(addressERC20, 5);
    // response = await tx.wait(1);
    // tx = await ERC721.setApprovalForAll(diamondAddress, true);
    // await tx.wait(1);
    // tx = await TokenFacet.mintAvalancheValidatorShareTokenERC721(addressERC721, [3,6,9], {gasLimit: 300_000});
    // response = await tx.wait(1);

    // tx = await TokenFacet.removeOracleAddress();
    // response = await tx.wait(1);

    // response = (await ViewTokenFacet.getTokenInfo(addressERC20)).toString();
    // console.log(response);
    // response = (await ViewTokenFacet.getTokenInfo(addressERC721)).toString();
    // console.log(response);
    // response = (await ViewTokenFacet.getTokenInfo(addressERC721));
    // [ 
    //     "BigNumber { _hex: '0x04', _isBigNumber: true },",
    //     false,
    //     "nameVariable: BigNumber { _hex: '0x04', _isBigNumber: true },",
    //     "nameVariable: false",
    // ]

    // response = (await ViewTokenFacet.getOraclePrice(addressERC20)).toString();
    // response = (await ViewTokenFacet.getOraclePrice(addressERC721)).toString();
    // console.log(response);

    // response = (await ViewTokenFacet.expiredOracle(addressERC20)).toString();
    // console.log(response);
    // response = (await ViewTokenFacet.expiredOracle(addressERC721)).toString();
    // console.log(response);

    // response = (await ViewTokenFacet.getShareCostTokenERC20(addressERC20, 6));
    // [ 
    //     "BigNumber { _hex: '0x04', _isBigNumber: true },",
    //     false
    // ]
    // console.log(response);
    // response = (await ViewTokenFacet.getShareMintTokenERC721(addressERC721, 3)).toString();
    // console.log(response);

    // response = (await ViewTokenFacet.getTokenPeriodAndLastTimestampUpdate(addressERC20)).toString();
    // console.log(response);

    // console.log(response);

    // tx = await AvalancheValidatorFacet.withdrawAvaxToStake();
    // await tx.wait(1);
}
main();