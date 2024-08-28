const { expect } = require("chai");
const { ethers } = require("ethers");
const Web3 = require('web3');
const assert = require('chai').assert;

const Controller = artifacts.require("ethController");
const EthVault = artifacts.require("ethVault");
const ETHStrategySpark = artifacts.require("ETHStrategySpark");
const ERC2O = artifacts.require("MockToken");
const AavePool = artifacts.require("AavePool");
const WETH = artifacts.require("WETH9");
const FlashloanReceiver = artifacts.require("FlashloanReceiver");
const Exchange = artifacts.require("Exchange");
const Aave =  artifacts.require("Aave");
const Oracle =  artifacts.require("mockOracle");

const LendingStrategySpark = artifacts.require("lendingStrategySpark");
const Vault = artifacts.require("Vault");
const MockVault = artifacts.require("MockVault");

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

    let lendingStrategySparkInst;
    let vaultInt;
    let lassetToken;
    let depositToken;
    let lIaavePool;

    before("init", async()=>{
        //init ethStrategy
        assetToken = await WETH.new();
        depositToken = await WETH.new();
        //
        // ethVaultInst = await EthVault.new(assetToken.address,"tokenspark","tk");
        //
        // aDepositAsset = await ERC2O.new();
        //
        let mockAaveInst = await Aave.new();
        //
        // IaavePool = await AavePool.new(mockAaveInst.address);
        //
        // let oracleInst = await Oracle.new();
        // eTHStrategySparkInst = await ETHStrategySpark.new(assetToken.address,depositToken.address,aDepositAsset.address,mlr,IaavePool.address,ethVaultInst.address,treasury,oracleInst.address,0);
        //
        // controllerInst = await Controller.new(ethVaultInst.address,eTHStrategySparkInst.address,assetToken.address,treasury);
        //
        // await ethVaultInst.setController(controllerInst.address);
        // await eTHStrategySparkInst.setController(controllerInst.address);
        //
        // let FlashloanReceiverInst = await FlashloanReceiver.new();
        //
        // await eTHStrategySparkInst.setFlashLoanReceiver(FlashloanReceiverInst.address);
        //
        // let  exchangeInst = await Exchange.new();
        //
        // await eTHStrategySparkInst.setExchange(exchangeInst.address);

        ////////////////////////////////////////////////////////////////////////////////////////
        ethVaultInst = await MockVault.new();
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
        lendingStrategySparkInst = await LendingStrategySpark.new(lassetToken.address,depositToken.address,5000,lIaavePool.address,vaultInt.address,ethVaultInst.address,feePool);

        let lControllerInst = await Controller.new(vaultInt.address,lendingStrategySparkInst.address,lassetToken.address,treasury);

        await vaultInt.setController(lControllerInst.address);
        await lendingStrategySparkInst.setController(lControllerInst.address);

        let  lEexchangeInst = await Exchange.new();
        await lendingStrategySparkInst.setExchange(lEexchangeInst.address);

    })

    it("601 deposit 10 token should correctly", async () => {
        let amount =  web3.utils.toWei('100', 'ether');
        let res =  await lassetToken.mint(alice,amount);
        assert.equal(res.receipt.status,true);

        let amount1 =  web3.utils.toWei('10', 'ether');
        await lassetToken.approve(vaultInt.address,amount1,{from:alice});


        res = await vaultInt.deposit(amount1,0,alice,{from:alice});
        assert.equal(res.receipt.status,true);

    });

    it("602 withdraw eth should correctly", async () => {
        let totalAsset = await vaultInt.totalAssets();
        let res = web3.utils.fromWei(totalAsset,"ether");
        console.log("total asset",res);

        let perShare = await vaultInt.assetsPerShare();
        res = web3.utils.fromWei(perShare,"ether");
        console.log("per share",res);

        let assetDebt = await lIaavePool.getCollateralAndDebt(lendingStrategySparkInst.address);
        res = web3.utils.fromWei(assetDebt[0],"ether");
        console.log("asset-debt",res);

        let amount =  web3.utils.toWei('10', 'ether');
        res = await vaultInt.withdraw(amount,0,bob,{from:alice});

        assert.equal(res.receipt.status,true);

    });

})


