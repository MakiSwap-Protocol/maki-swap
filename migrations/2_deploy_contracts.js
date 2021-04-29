const Factory = artifacts.require('MakiSwapFactory.sol');
const Router = artifacts.require('MakiSwapRouter.sol');
const WTH = artifacts.require('WTH.sol');
const MockHRC20 = artifacts.require('MockHRC20.sol');
const Multicall = artifacts.require('Multicall.sol');

module.exports = async function(deployer, addresses) {
  
  // Deploy Mock Tokens
    await deployer.deploy(WTH);
    const wht = await WHT.deployed();
    const tokenA = await MockHRC20.new('Token A', 'TKA', web3.utils.toWei('1000'));
    const tokenB = await MockHRC20.new('Token B', 'TKB', web3.utils.toWei('1000'));
  
  // Deploy Factory and Multicall
    await deployer.deploy(Factory, addresses[0]); // alt process.env.ADMIN_ADDRESS
    const factory = await Factory.deployed();

    await deployer.deploy(Multicall);

  // Create LP Pair
    await factory.createPair(wht.address, tokenA.address);
    await factory.createPair(wht.address, tokenB.address);
    
    await deployer.deploy(Router, factory.address, wht.address);
    const router = await Router.deployed();

}
