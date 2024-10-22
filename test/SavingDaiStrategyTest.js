const { expect } = require("chai");
const { ethers } = require("ethers");
const Web3 = require('web3');
const assert = require('chai').assert;

const Controller = artifacts.require("ethController");
const EthVault = artifacts.require("ethVault");
const SavingDaiStrategy = artifacts.require("SavingDaiStrategy");
const ERC2O = artifacts.require("MockToken");
const AavePool = artifacts.require("AavePool");
const WETH = artifacts.require("WETH9");
const FlashloanReceiver = artifacts.require("FlashloanReceiver");
const Exchange = artifacts.require("Exchange");
const Aave =  artifacts.require("Aave");
const Oracle =  artifacts.require("mockOracle");

//const LendingStrategySpark = artifacts.require("lendingStrategySpark");
const Vault = artifacts.require("Vault");
const MockVault = artifacts.require("MockVault");
const MockVault4626 = artifacts.require("MockERC4626");

contract('Vault', (accounts) => {

    web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

    const alice = accounts[1];
    const bob = accounts[2];
    const treasury =  accounts[3];

    let controllerInst;
    let ethVaultInst;
    let eTHStrategySparkInst;
    let assetToken;

    let baseAsset;
    let depositAsset;
   // let aDepositAsset;
    let IaavePool;
    let feePool = accounts[4];
    let mlr = 5000;

    let savingDaiStrategyInst;
    let vaultInt;
    let lassetToken;
    let depositToken;
    let lIaavePool;
    let savingDaiInt;

    before("init", async()=>{
        //init ethStrategy
        assetToken = await WETH.new();
        depositToken = await WETH.new();

        savingDaiInt = await MockVault4626.new(assetToken.address);

        let mockAaveInst = await Aave.new();
 
        ////////////////////////////////////////////////////////////////////////////////////////
        ethVaultInst = await MockVault.new(savingDaiInt.address);

        lIaavePool = await AavePool.new(mockAaveInst.address);
   
        //init lendingStrategy
        lassetToken = await ERC2O.new();
        vaultInt = await Vault.new(lassetToken.address,"tokenspark","tk");
        // IERC20 _depositAsset,
        //     address _weth,
        //     uint256 _mlr,
        //     address _IaavePool,
        //     address _vault,
        //     address _ethLeverage,
        //     address _feePool
        savingDaiStrategyInst = await SavingDaiStrategy.new(savingDaiInt.address,lassetToken.address,depositToken.address,5000,lIaavePool.address,vaultInt.address,ethVaultInst.address,feePool);

        let lControllerInst = await Controller.new(vaultInt.address,savingDaiStrategyInst.address,lassetToken.address,treasury);

        await vaultInt.setController(lControllerInst.address);
        await savingDaiStrategyInst.setController(lControllerInst.address);

        let  lEexchangeInst = await Exchange.new();
        await savingDaiStrategyInst.setExchange(lEexchangeInst.address);

    })

    it("801 deposit 10 token should correctly", async () => {
        let amount =  web3.utils.toWei('100', 'ether');
        let res =  await lassetToken.mint(alice,amount);
        assert.equal(res.receipt.status,true);

        let amount1 =  web3.utils.toWei('10', 'ether');
        await lassetToken.approve(vaultInt.address,amount1,{from:alice});


        res = await vaultInt.deposit(amount1,0,alice,{from:alice});
        assert.equal(res.receipt.status,true);

    });

    it("802 redeem token should correctly", async () => {
        let totalAsset = await vaultInt.totalAssets();
        let res = web3.utils.fromWei(totalAsset,"ether");
        console.log("total asset",res);

        let perShare = await vaultInt.assetsPerShare();
        res = web3.utils.fromWei(perShare,"ether");
        console.log("per share",res);

        let assetDebt = await lIaavePool.getCollateralAndDebt(savingDaiStrategyInst.address);
        res = web3.utils.fromWei(assetDebt[0],"ether");
        console.log("asset-debt",res);

        let amount =  web3.utils.toWei('10', 'ether');
        res = await vaultInt.redeem(amount,0,bob,{from:alice});

        assert.equal(res.receipt.status,true);

    });

})


