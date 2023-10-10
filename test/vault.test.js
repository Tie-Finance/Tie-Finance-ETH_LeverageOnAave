const { expect } = require("chai");
const { ethers } = require("ethers");


const INFVault = artifacts.require("./INFVault.sol")
const Controller = artifacts.require("./Controller.sol")
const ETHStrategy = artifacts.require("./ETHStrategy.sol")
const ETHLeverExchange = artifacts.require("./ETHLeverExchange.sol")
const BalancerReceiver = artifacts.require("./BalancerReceiver.sol")
const ETHStrategyTest = artifacts.require("./ETHStrategyTest.sol")
const WhiteList = artifacts.require("./Whitelist.sol")

contract('Vault', (accounts) => {
    const alice = accounts[1];
    const bob = accounts[2];

    it("should whitelist set correctly", async () => {
        const whitelist = await WhiteList.deployed();

        const eoaIswhitelist =await whitelist.isWhitelisted(alice);
        expect(eoaIswhitelist).to.equal(true);

        const caIswhitelist =await whitelist.isWhitelisted(ETHStrategy.address);
        expect(caIswhitelist).to.equal(false);

        await whitelist.setWhitelist(ETHStrategy.address, true);
        const caIswhitelist1 =await whitelist.isWhitelisted(ETHStrategy.address);
        expect(caIswhitelist1).to.equal(true);
    });

    it("should deposit correctly", async () => {
        const vaultInstance = await INFVault.deployed();
        const strategy1 = await ETHStrategy.deployed();
        const strategy2 = await ETHStrategyTest.deployed();
        const depositamount = "2000";
        // alice depoist 1 eth
        await vaultInstance.deposit(ethers.parseEther(depositamount).toString(), alice, { from: alice, value: ethers.parseEther(depositamount).toString() });



        // first depoist, lp = deposit amount
        const aliceLp = await vaultInstance.balanceOf(alice);
        console.log(`alice deposit ${depositamount} eth lp is ${aliceLp}`)

        const totalAssets = await vaultInstance.totalAssets();
        console.log(`alice deposit ${depositamount} eth vault total assets is ${totalAssets}`)
        const totalsupply = await vaultInstance.totalSupply();
        console.log(`vault total supply is ${totalsupply}`)

        const strategy1Assets = await strategy1.totalAssets();
        console.log(`alice deposit ${depositamount} eth strategy1 total assets is ${strategy1Assets}`)

        const strategy2Assets = await strategy2.totalAssets();
        console.log(`alice deposit ${depositamount} eth strategy2 total assets is ${strategy2Assets}`)
    });

    it("should withdraw correctly", async () => {
        const vaultInstance = await INFVault.deployed();
        const strategy1 = await ETHStrategy.deployed();
        const strategy2 = await ETHStrategyTest.deployed();
        const withamount = '1950';
        // alice withdraw 0.5 eth
        await vaultInstance.withdraw(ethers.parseEther(withamount).toString(), alice, { from: alice });

        const aliceLp2 = await vaultInstance.balanceOf(alice);
        console.log(`alice withdraw ${withamount} eth lp is ${aliceLp2}`)

        const totalAssets2 = await vaultInstance.totalAssets();
        const totalsupply = await vaultInstance.totalSupply();
        console.log(`alice withdraw ${withamount} eth, vault total assets is ${totalAssets2}`)
        console.log(`vault total supply is ${totalsupply}`)

        const strategy1Assets = await strategy1.totalAssets();
        console.log(`alice withdraw ${withamount} eth, strategy1 total assets is ${strategy1Assets}`)

        const strategy2Assets = await strategy2.totalAssets();
        console.log(`alice withdraw ${withamount} eth, strategy2 total assets is ${strategy2Assets}`)
    });




    it("should harvest correctly", async () => {
        const vaultInstance = await INFVault.deployed();
        const strategy1 = await ETHStrategy.deployed();
        const treasury = "0xF2bb9641694Baa6848338CD40993681Fee936a12";
        let balance = await vaultInstance.balanceOf(treasury)
        console.log(`Treasury address  before deposit balance  is ${balance}`)
        // const strategy2 = await ETHStrategyTest.deployed();

        // alice depoist 50 eth
        await vaultInstance.deposit(ethers.parseEther('50').toString(), alice, { from: alice, value: ethers.parseEther('50').toString() });
        // first depoist, lp = deposit amount
        const aliceLp = await vaultInstance.balanceOf(alice);
        console.log(`alice deposit 50 eth lp is ${aliceLp}`)

        const totalAssets = await vaultInstance.totalAssets();
        console.log(`alice deposit 50 eth vault total assets is ${totalAssets}`)

        console.log(`start harvest =====`)
        await new Promise(r => setTimeout(r, 2000));
        let balanceStart = await vaultInstance.balanceOf(treasury)
        console.log(`Treasury address  after deposit balance  is ${balanceStart}`)
        const strategyHavest = await strategy1.harvest();
        const totalAssetsEnd = await vaultInstance.totalAssets();
        let balanceEnd = await vaultInstance.balanceOf(treasury)
        const aliceLpEnd = await vaultInstance.balanceOf(alice);
        console.log(`Harvest alice  lp is ${aliceLpEnd}`)
        console.log(`Treasury address  end balance  is ${balanceEnd}`)
        console.log(`end harvest  valut total assets is ${totalAssetsEnd}`)

    });





    it("should redeem correctly", async () => {
        const vaultInstance = await INFVault.deployed();
        const strategy1 = await ETHStrategy.deployed();
        const strategy2 = await ETHStrategyTest.deployed();
        // alice redeem 0.1 lp
        await vaultInstance.redeem(ethers.parseEther('0.1').toString(), alice, { from: alice });
        const aliceLp3 = await vaultInstance.balanceOf(alice);
        console.log(`alice redeem 0.1 lp remain is ${aliceLp3}`)

        const totalAssets3 = await vaultInstance.totalAssets();
        console.log(`alice redeem 0.1 lp  then total assets is ${totalAssets3}`)

        const strategy1Assets = await strategy1.totalAssets();
        console.log(`alice redeem 0.1 lp , strategy1 total assets is ${strategy1Assets}`)

        const strategy2Assets = await strategy2.totalAssets();
        console.log(`alice redeem 0.1 lp , strategy2 total assets is ${strategy2Assets}`)
    });

})
