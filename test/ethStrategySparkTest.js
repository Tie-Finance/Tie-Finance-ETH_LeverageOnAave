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

    before("init", async()=>{
        assetToken = await WETH.new();
        let depositToken = await WETH.new();
        
        ethVaultInst = await EthVault.new(assetToken.address,"tokenspark","tk");

        aDepositAsset = await ERC2O.new();

        let mockAaveInst = await Aave.new();

        IaavePool = await AavePool.new(mockAaveInst.address);

        let oracleInst = await Oracle.new();
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
        await eTHStrategySparkInst.setController(controllerInst.address);

        let FlashloanReceiverInst = await FlashloanReceiver.new();

        await eTHStrategySparkInst.setFlashLoanReceiver(FlashloanReceiverInst.address);

        let  exchangeInst = await Exchange.new();

        await eTHStrategySparkInst.setExchange(exchangeInst.address);

    })

    it("301 deposit 10 eth should correctly", async () => {
        let amount =  web3.utils.toWei('10', 'ether');

        let res = await ethVaultInst.depositEth(0,alice,{from:alice,value:amount});

        assert.equal(res.receipt.status,true);

    });

    it("302 withdraw eth should correctly", async () => {
        let totalAsset = await ethVaultInst.totalAssets();
        let res = web3.utils.fromWei(totalAsset,"ether");
        console.log("total asset",res);

        let perShare = await ethVaultInst.assetsPerShare();
        res = web3.utils.fromWei(perShare,"ether");
        console.log("per share",res);

        let assetDebt = await IaavePool.getCollateralAndDebt(eTHStrategySparkInst.address);
       // console.log(assetDebt);

        res = web3.utils.fromWei(assetDebt[0],"ether");
        console.log("asset-debt",res);

        let amount =  web3.utils.toWei('10', 'ether');
        await aDepositAsset.mint(eTHStrategySparkInst.address,amount);

        res = await ethVaultInst.withdrawEth(amount,0,bob,{from:alice});

        assert.equal(res.receipt.status,true);

    });

})



