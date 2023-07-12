import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract, Signer } from "ethers";

describe("YieldFarming", function () {
  let yieldFarming: Contract;
  let compound: Contract;
  let uniswap: Contract;
  let externalStore: Contract;

  beforeEach(async function () {
    const YieldFarming = await ethers.getContractFactory("YieldFarming");
    const Compound = await ethers.getContractFactory("CompoundController");
    const UniswapV2Router02 = await ethers.getContractFactory("UniswapV2Router02");
    const ExternalStore = await ethers.getContractFactory("ExternalStore");

    compound = await Compound.deploy();
    uniswap = await UniswapV2Router02.deploy();
    externalStore = await ExternalStore.deploy("");

    yieldFarming = await YieldFarming.deploy(compound.address, uniswap.address, externalStore.address);
  });

  it("should deposit and withdraw successfully", async function () {
    // Mock token addresses
    const asset = "0x6B175474E89094C44Da98b954EedeAC495271d0F"; // DAI
    const borrowAsset = "0xdAC17F958D2ee523a2206206994597C13D831ec7"; // USDT
    const path = ["0x6B175474E89094C44Da98b954EedeAC495271d0F", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"]; // DAI to WETH
    const amounts = [1000, 1000]; // Amounts for swapping

    // Deposit
    await yieldFarming.deposit(asset, 1000, borrowAsset, 1000, path, amounts);

    // Assert ERC1155 balances in external store
    const assetBalance = await externalStore.balanceOf(yieldFarming.address, 1);
    const borrowAssetBalance = await externalStore.balanceOf(yieldFarming.address, 2);
    const liquidityBalance = await externalStore.balanceOf(yieldFarming.address, 11);
    expect(assetBalance).to.equal(1000);
    expect(borrowAssetBalance).to.equal(1000);
    expect(liquidityBalance).to.be.above(0);

    // Withdraw
    await yieldFarming.withdraw(asset, 1000, borrowAsset, 1000, path, amounts);

    // Assert ERC1155 balances in external store after withdrawal
    const assetBalanceAfterWithdrawal = await externalStore.balanceOf(yieldFarming.address, 1);
    const borrowAssetBalanceAfterWithdrawal = await externalStore.balanceOf(yieldFarming.address, 2);
    const liquidityBalanceAfterWithdrawal = await externalStore.balanceOf(yieldFarming.address, 11);
    expect(assetBalanceAfterWithdrawal).to.equal(0);
    expect(borrowAssetBalanceAfterWithdrawal).to.equal(0);
    expect(liquidityBalanceAfterWithdrawal).to.equal(0);
  });
});