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
    let aDepositAsset;
    let IaavePool;
    let feePool = accounts[4];
    let mlr = 5000;
    let oracleInst;
    let FlashloanReceiverInst;
    let  exchangeInst;

    before("init", async()=>{
        assetToken = await WETH.new();
        let depositToken = await WETH.new();
        
        ethVaultInst = await EthVault.new(assetToken.address,"tokenspark","tk");

        aDepositAsset = await ERC2O.new();

        let mockAaveInst = await Aave.new();

        IaavePool = await AavePool.new(mockAaveInst.address);

        oracleInst = await Oracle.new();
        // IERC20 _baseAsset,
        //     IERC20 _depositAsset,
        //     IERC20 _aDepositAsset,
        //     uint256 _mlr,
        //     address _IaavePool,
        //     address _vault,
        //     address _feePool,
        //     uint8 _emode
        eTHStrategySparkInst = await ETHStrategySpark.new(assetToken.address,depositToken.address,aDepositAsset.address,mlr,IaavePool.address,ethVaultInst.address,treasury,oracleInst.address,0);

        controllerInst = await Controller.new(ethVaultInst.address,eTHStrategySparkInst.address,assetToken.address,treasury);

        await ethVaultInst.setController(controllerInst.address);


        FlashloanReceiverInst = await FlashloanReceiver.new();

        await eTHStrategySparkInst.setFlashLoanReceiver(FlashloanReceiverInst.address);

        exchangeInst = await Exchange.new();

        await eTHStrategySparkInst.setExchange(exchangeInst.address);

    })

    it("100 strategy set controller,should pass", async () => {
        let res = await eTHStrategySparkInst.setController(controllerInst.address);
      //  console.log(res);
        assert.equal(res.receipt.status,true);

    });

    it("101 strategy set operator,should pass", async () => {
        let res = await eTHStrategySparkInst.setOperator(alice,true);
        //  console.log(res);
        assert.equal(res.receipt.status,true);

    });

    it("102 strategy set fee pool,should pass", async () => {
        let res = await eTHStrategySparkInst.setFeePool(bob);
        //  console.log(res);
        assert.equal(res.receipt.status,true);
    });

    it("103 strategy set Max Deposit,should pass", async () => {
        let amount =  web3.utils.toWei('10000', 'ether');
        let res = await eTHStrategySparkInst.setMaxDeposit(amount);
        //  console.log(res);
        assert.equal(res.receipt.status,true);
    });


    it("104 strategy set flash loan reciever,should pass", async () => {
        let res = await eTHStrategySparkInst.setFlashLoanReceiver(FlashloanReceiverInst.address);
        //  console.log(res);
        assert.equal(res.receipt.status,true);
    });


    it("105 strategy set oracle,should pass", async () => {
        let res = await eTHStrategySparkInst.setOracle(oracleInst.address);
        //  console.log(res);
        assert.equal(res.receipt.status,true);
    });


    it("106 strategy set exchanger,should pass", async () => {
        let res = await eTHStrategySparkInst.setExchange(exchangeInst.address);
        //  console.log(res);
        assert.equal(res.receipt.status,true);
    });

    it("107 strategy set fee rate,should pass", async () => {
        let res = await eTHStrategySparkInst.setFeeRate(200);
        //  console.log(res);
        assert.equal(res.receipt.status,true);
    });

    it("108 strategy set MLR,should pass", async () => {
        let res = await eTHStrategySparkInst.setMLR(5000,50,{from:alice});
        //  console.log(res);
        assert.equal(res.receipt.status,true);
    });


})



