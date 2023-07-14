import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
let owner: SignerWithAddress;
let user1: SignerWithAddress;
let user2: SignerWithAddress;
let team: SignerWithAddress;

let TokenPool1: Contract;
let TokenPool2: Contract;
let TokenPool3: Contract;
let PoolFactory: Contract;
let UniswapRouter: Contract;

let RewardToken: Contract;
let UNIToken: Contract;
let WETH: Contract;
let DAI: Contract;
let compound: Contract;
let uniswap: Contract;
let externalStore: Contract;
let yieldFarming: Contract;
let Oracle1: Contract;
let Oracle2: Contract;
describe("YieldFarming", function () {
beforeEach(async () => {
  [owner, user1, user2, team] = await ethers.getSigners();

  RewardToken = await ethers.getContractAt(
    "IERC20",
    "0x514910771AF9Ca656af840dff83E8264EcF986CA"
  );

  UNIToken = await ethers.getContractAt(
    "IERC20",
    "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"
  );

  DAI = await ethers.getContractAt(
    "IERC20",
    "0x6B175474E89094C44Da98b954EedeAC495271d0F"
  );

  const UniswapRouterABI = require("./ABI/UniswapRouter.json");
  UniswapRouter = await ethers.getContractAt(
    UniswapRouterABI,
    "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
  );

  const uniswapFactoryAddress = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";

  WETH = await ethers.getContractAt(
    "IERC20",
    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  );


  const currentTime = (await ethers.provider.getBlock("latest")).timestamp;

  await UniswapRouter.connect(team).swapETHForExactTokens(
    10000000,
    [WETH.address, RewardToken.address],
    team.address,
    currentTime + 100000,
    { value: ethers.utils.parseEther("1000") }
  );
  await UniswapRouter.connect(user1).swapETHForExactTokens(
    10000000,
    [WETH.address, DAI.address],
    user1.address,
    currentTime + 100000,
    { value: ethers.utils.parseEther("1000") }
  );
  await UniswapRouter.connect(user2).swapETHForExactTokens(
    1000000,
    [WETH.address, DAI.address],
    user2.address,
    currentTime + 100000,
    { value: ethers.utils.parseEther("100") }
  );

  await UniswapRouter.connect(user1).swapETHForExactTokens(
    1000000,
    [WETH.address, UNIToken.address],
    user1.address,
    currentTime + 100000,
    { value: ethers.utils.parseEther("100") }
  );
  await UniswapRouter.connect(user2).swapETHForExactTokens(
    1000000,
    [WETH.address, UNIToken.address],
    user2.address,
    currentTime + 100000,
    { value: ethers.utils.parseEther("100") }
  );
    const YieldFarming = await ethers.getContractFactory("YieldFarming");
    const Compound = await ethers.getContractFactory("CompoundController");
    const ExternalStore = await ethers.getContractFactory("ExternalStore");

    compound = await Compound.deploy();
    externalStore = await ExternalStore.deploy("");

    yieldFarming = await YieldFarming.deploy(compound.address, UniswapRouter.address, externalStore.address);
});

    // const oracle1Addr = await TokenPool1.getOracleAddress();
    // Oracle1 = await ethers.getContractAt("Oracle", oracle1Addr);
    // const oracle2Addr = await TokenPool2.getOracleAddress();
    // Oracle2 = await ethers.getContractAt("Oracle", oracle2Addr);
  
  it("should deposit and withdraw successfully", async function () {
    console.log("1 " , user1.address);
    const UNITokenAmount =await UNIToken.connect(user1).balanceOf(user1.address);
    console.log(UNITokenAmount);
    const DAITokenAmount =await DAI.connect(user1).balanceOf(user1.address);
    console.log(DAITokenAmount);
    console.log("2 " , user2.address);

    const asset = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"; // UNIToken
    const borrowAsset = "0xdAC17F958D2ee523a2206206994597C13D831ec7"; // USDT
    const path = ["0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"]; // DAI to WETH
    const amounts = [1000, 1000]; // Amounts for swapping

    // Deposit
    await UNIToken.connect(user1).approve(yieldFarming.address, 1000);
    await yieldFarming.connect(user1).deposit(asset, 1000, borrowAsset, 1000, path, amounts);
  });
//   let yieldFarming: Contract;
//   let compound: Contract;
//   let uniswap: Contract;
//   let externalStore: Contract;

//   beforeEach(async function () {
//     const YieldFarming = await ethers.getContractFactory("YieldFarming");
//     const Compound = await ethers.getContractFactory("CompoundController");
//     const UniswapV2Router02 = await ethers.getContractFactory("IUniswapV2Router02");
//     const ExternalStore = await ethers.getContractFactory("ExternalStore");

//     compound = await Compound.deploy();
//     uniswap = await UniswapV2Router02.deploy();
//     externalStore = await ExternalStore.deploy("");

//     yieldFarming = await YieldFarming.deploy(compound.address, uniswap.address, externalStore.address);
//   });

//   it("should deposit and withdraw successfully", async function () {
//     // Mock token addresses
//     const asset = "0x6B175474E89094C44Da98b954EedeAC495271d0F"; // DAI
//     const borrowAsset = "0xdAC17F958D2ee523a2206206994597C13D831ec7"; // USDT
//     const path = ["0x6B175474E89094C44Da98b954EedeAC495271d0F", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"]; // DAI to WETH
//     const amounts = [1000, 1000]; // Amounts for swapping

//     // Deposit
//     await yieldFarming.deposit(asset, 1000, borrowAsset, 1000, path, amounts);

//     // Assert ERC1155 balances in external store
//     const assetBalance = await externalStore.balanceOf(yieldFarming.address, 1);
//     const borrowAssetBalance = await externalStore.balanceOf(yieldFarming.address, 2);
//     const liquidityBalance = await externalStore.balanceOf(yieldFarming.address, 11);
//     expect(assetBalance).to.equal(1000);
//     expect(borrowAssetBalance).to.equal(1000);
//     expect(liquidityBalance).to.be.above(0);

//     // Withdraw
//     await yieldFarming.withdraw(asset, 1000, borrowAsset, 1000, path, amounts);

//     // Assert ERC1155 balances in external store after withdrawal
//     const assetBalanceAfterWithdrawal = await externalStore.balanceOf(yieldFarming.address, 1);
//     const borrowAssetBalanceAfterWithdrawal = await externalStore.balanceOf(yieldFarming.address, 2);
//     const liquidityBalanceAfterWithdrawal = await externalStore.balanceOf(yieldFarming.address, 11);
//     expect(assetBalanceAfterWithdrawal).to.equal(0);
//     expect(borrowAssetBalanceAfterWithdrawal).to.equal(0);
//     expect(liquidityBalanceAfterWithdrawal).to.equal(0);
//   });
});