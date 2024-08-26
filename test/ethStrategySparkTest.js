const { expect } = require("chai");
const { ethers } = require("ethers");
const Web3 = require('web3');


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

    it("deposit 10 eth should correctly", async () => {   
        let amount =  web3.utils.toWei('10', 'ether');
        await ethVaultInst.depositEth(0,alice,{from:alice,value:amount});

    });

    it("withdraw eth should correctly", async () => {
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

        await ethVaultInst.withdrawEth(amount,0,bob,{from:alice});

    });

})


//     it("should deposit correctly", async () => {
//         const vaultInstance = await INFVault.deployed();
//         const strategy1 = await ETHStrategy.deployed();
//         const strategy2 = await ETHStrategyTest.deployed();
//         const depositamount = "2000";
//         // alice depoist 1 eth
//         await vaultInstance.deposit(ethers.parseEther(depositamount).toString(), alice, { from: alice, value: ethers.parseEther(depositamount).toString() });



//         // first depoist, lp = deposit amount
//         const aliceLp = await vaultInstance.balanceOf(alice);
//         console.log(`alice deposit ${depositamount} eth lp is ${aliceLp}`)

//         const totalAssets = await vaultInstance.totalAssets();
//         console.log(`alice deposit ${depositamount} eth vault total assets is ${totalAssets}`)
//         const totalsupply = await vaultInstance.totalSupply();
//         console.log(`vault total supply is ${totalsupply}`)

//         const strategy1Assets = await strategy1.totalAssets();
//         console.log(`alice deposit ${depositamount} eth strategy1 total assets is ${strategy1Assets}`)

//         const strategy2Assets = await strategy2.totalAssets();
//         console.log(`alice deposit ${depositamount} eth strategy2 total assets is ${strategy2Assets}`)
//     });

//     it("should withdraw correctly", async () => {
//         const vaultInstance = await INFVault.deployed();
//         const strategy1 = await ETHStrategy.deployed();
//         const strategy2 = await ETHStrategyTest.deployed();
//         const withamount = '1950';
//         // alice withdraw 0.5 eth
//         await vaultInstance.withdraw(ethers.parseEther(withamount).toString(), alice, { from: alice });

//         const aliceLp2 = await vaultInstance.balanceOf(alice);
//         console.log(`alice withdraw ${withamount} eth lp is ${aliceLp2}`)

//         const totalAssets2 = await vaultInstance.totalAssets();
//         const totalsupply = await vaultInstance.totalSupply();
//         console.log(`alice withdraw ${withamount} eth, vault total assets is ${totalAssets2}`)
//         console.log(`vault total supply is ${totalsupply}`)

//         const strategy1Assets = await strategy1.totalAssets();
//         console.log(`alice withdraw ${withamount} eth, strategy1 total assets is ${strategy1Assets}`)

//         const strategy2Assets = await strategy2.totalAssets();
//         console.log(`alice withdraw ${withamount} eth, strategy2 total assets is ${strategy2Assets}`)
//     });




//     it("should harvest correctly", async () => {
//         const vaultInstance = await INFVault.deployed();
//         const strategy1 = await ETHStrategy.deployed();
//         const treasury = "0xF2bb9641694Baa6848338CD40993681Fee936a12";
//         let balance = await vaultInstance.balanceOf(treasury)
//         console.log(`Treasury address  before deposit balance  is ${balance}`)
//         // const strategy2 = await ETHStrategyTest.deployed();

//         // alice depoist 50 eth
//         await vaultInstance.deposit(ethers.parseEther('50').toString(), alice, { from: alice, value: ethers.parseEther('50').toString() });
//         // first depoist, lp = deposit amount
//         const aliceLp = await vaultInstance.balanceOf(alice);
//         console.log(`alice deposit 50 eth lp is ${aliceLp}`)

//         const totalAssets = await vaultInstance.totalAssets();
//         console.log(`alice deposit 50 eth vault total assets is ${totalAssets}`)

//         console.log(`start harvest =====`)
//         await new Promise(r => setTimeout(r, 2000));
//         let balanceStart = await vaultInstance.balanceOf(treasury)
//         console.log(`Treasury address  after deposit balance  is ${balanceStart}`)
//         const strategyHavest = await strategy1.harvest();
//         const totalAssetsEnd = await vaultInstance.totalAssets();
//         let balanceEnd = await vaultInstance.balanceOf(treasury)
//         const aliceLpEnd = await vaultInstance.balanceOf(alice);
//         console.log(`Harvest alice  lp is ${aliceLpEnd}`)
//         console.log(`Treasury address  end balance  is ${balanceEnd}`)
//         console.log(`end harvest  valut total assets is ${totalAssetsEnd}`)

//     });





//     it("should redeem correctly", async () => {
//         const vaultInstance = await INFVault.deployed();
//         const strategy1 = await ETHStrategy.deployed();
//         const strategy2 = await ETHStrategyTest.deployed();
//         // alice redeem 0.1 lp
//         await vaultInstance.redeem(ethers.parseEther('0.1').toString(), alice, { from: alice });
//         const aliceLp3 = await vaultInstance.balanceOf(alice);
//         console.log(`alice redeem 0.1 lp remain is ${aliceLp3}`)

//         const totalAssets3 = await vaultInstance.totalAssets();
//         console.log(`alice redeem 0.1 lp  then total assets is ${totalAssets3}`)

//         const strategy1Assets = await strategy1.totalAssets();
//         console.log(`alice redeem 0.1 lp , strategy1 total assets is ${strategy1Assets}`)

//         const strategy2Assets = await strategy2.totalAssets();
//         console.log(`alice redeem 0.1 lp , strategy2 total assets is ${strategy2Assets}`)
//     });


