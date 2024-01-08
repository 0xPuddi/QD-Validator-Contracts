async function deploySimpleContract (contractName, name, symbol) {
    // deploy DiamondCutFacet
    const contract = await ethers.getContractFactory(contractName)
    const deployedContract = await contract.deploy(name, symbol)
    await deployedContract.deployed()

    console.log(contractName + ' Deployed at address: ' + deployedContract.address)

    return deployedContract.address
}

async function main() {
    await deploySimpleContract('ERC721', 'testERC721', 'T721');
    await deploySimpleContract('ERC20', 'testERC20', 'T20');
}

main();

exports.deploySimpleContract = deploySimpleContract