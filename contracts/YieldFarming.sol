// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interface/CompoundInterface.sol";



interface IExternalStore {
    function wrap(address user, uint256 amount, uint256 id) external;
    function burn(address user, uint256 id, uint256 amount) external;
    function balanceOf(address user, uint256 id) external returns (uint256);
}

contract YieldFarming is ERC1155Holder, Ownable {
    ICompound public compound;
    IUniswapV2Router02 public uniswap;
    IExternalStore public externalStore;

    uint256 public constant DAI_WETH_POOL_ID = 1;

    constructor(address _compound, address _uniswap, address _externalStore) {
        compound = ICompound(_compound);
        uniswap = IUniswapV2Router02(_uniswap);
        externalStore = IExternalStore(_externalStore);
    }

    function deposit(address asset, uint256 assetAmount, address borrowAsset, uint256 borrowAmount, address[] memory path, uint256[] memory amounts) external {
        // Transfer asset from user to this contract
        IERC20(asset).transferFrom(msg.sender, address(this), assetAmount);

        // Supply asset to Compound
        IERC20(asset).approve(address(compound), assetAmount);
        compound.supply(asset, borrowAsset, assetAmount);

        // Borrow asset from Compound
        IERC20(borrowAsset).approve(address(compound), borrowAmount);
        compound.borrow(asset, borrowAsset, borrowAmount);

        // Swap half of borrowed asset to WETH
        uint256[] memory swapAmounts = new uint256[](path.length);
        swapAmounts[0] = borrowAmount / 2;

        for (uint256 i = 1; i < path.length; i++) {
            swapAmounts[i] = getSwapAmount(path[i - 1], path[i], swapAmounts[i - 1]);
        }

        IERC20(path[0]).approve(address(uniswap), swapAmounts[0]);
        uniswap.swapExactTokensForTokens(swapAmounts[0], 0, path, address(this), block.timestamp + 1800);

        // Add liquidity to asset/WETH pool
        IERC20 weth = IERC20(getTokenAddress("WETH"));
        IERC20(path[path.length - 1]).approve(address(uniswap), amounts[amounts.length - 1]);
        (,, uint256 liquidity) = uniswap.addLiquidity(path[0], path[path.length - 1], swapAmounts[0], amounts[amounts.length - 1], 0, 0, address(this), block.timestamp + 1800);

        // Wrap deposited information to ERC1155 and store to ExternalStore contract
        externalStore.wrap(msg.sender, assetAmount, getTokenId(asset));
        externalStore.wrap(msg.sender, borrowAmount, getTokenId(borrowAsset));
        externalStore.wrap(msg.sender, liquidity, getTokenId(asset)+10);
    }

    function withdraw(address asset, uint256 assetAmount, address borrowAsset, uint256 borrowAmount, address[] memory path, uint256[] memory amounts) external {
        // Burn ERC1155
        uint256 liquidity = externalStore.balanceOf(msg.sender, getTokenId(asset)+10);
        externalStore.burn(msg.sender, getTokenId(asset), assetAmount);
        externalStore.burn(msg.sender, getTokenId(borrowAsset), borrowAmount);
        externalStore.burn(msg.sender, getTokenId(asset)+10, liquidity);

        // Remove liquidity from asset/WETH pool
        IERC20 weth = IERC20(getTokenAddress("WETH"));
        IERC20(path[path.length - 1]).approve(address(uniswap), amounts[amounts.length - 1]);
        (uint256 amountA, uint256 amountB) = uniswap.removeLiquidity(path[0], path[path.length - 1], liquidity, 0, 0, address(this), block.timestamp + 1800);

        // Swap WETH to asset
        uint256[] memory swapAmounts = new uint256[](path.length);
        swapAmounts[swapAmounts.length - 1] = amountB;

        for (uint256 i = swapAmounts.length - 2; i >= 0; i--) {
            swapAmounts[i] = getSwapAmount(path[i + 1], path[i], swapAmounts[i + 1]);
        }

        IERC20(path[path.length - 1]).approve(address(uniswap), swapAmounts[0]);
        uniswap.swapExactTokensForTokens(swapAmounts[0], 0, path, address(this), block.timestamp + 1800);

        // Repay asset debt to Compound
        IERC20(asset).approve(address(compound), borrowAmount);
        compound.repayBorrow(asset, borrowAsset, borrowAmount);

        // Redeem asset from Compound
        IERC20(asset).approve(address(compound), assetAmount);
        compound.repayBorrow(asset, borrowAsset, assetAmount);
    }
    function getTokenId(address token) private pure returns (uint256) {
        if (token == address(0x6B175474E89094C44Da98b954EedeAC495271d0F)) { //DAI
            return 1;
        } else if (token == address(0xdAC17F958D2ee523a2206206994597C13D831ec7)) { //USDT
            return 2;
        } else if (token == address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984)) { //UNI
            return 3;
        } else {
            revert("Unsupported token address");
        }
    }

    function getBorrowAmount(address asset, uint256 assetAmount, address borrowAsset) private view returns (uint256) {
        uint256 assetPrice = getAssetPrice(asset);
        uint256 borrowAssetPrice = getAssetPrice(borrowAsset);
        uint256 borrowAmount = (assetAmount * assetPrice) / borrowAssetPrice;
        return borrowAmount;
    }

    function getSwapAmount(address fromToken, address toToken, uint256 amountIn) private view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        uint256[] memory amountsOut = uniswap.getAmountsOut(amountIn, path);
        return amountsOut[amountsOut.length - 1];
    }

    function getAssetPrice(address asset) private view returns (uint256) {
        (, int256 price, , , ) = AggregatorV3Interface(getPriceFeedAddress(asset)).latestRoundData();
        return uint256(price);
    }
    function getTokenAddress(string memory symbol) private pure returns (address) {
        if (keccak256(bytes(symbol)) == keccak256(bytes("DAI"))) {
            return 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        } else if (keccak256(bytes(symbol)) == keccak256(bytes("WETH"))) {
            return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        } else if (keccak256(bytes(symbol)) == keccak256(bytes("USDT"))) {
            return 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        } else if (keccak256(bytes(symbol)) == keccak256(bytes("UNI"))) {
            return 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        } else {
            revert("Unsupported token symbol");
        }
    }
    function getPriceFeedAddress(address asset) private pure returns (address) {
        if (asset == address(0x6B175474E89094C44Da98b954EedeAC495271d0F)) {
            return 0x773616E4d11A78F511299002da57A0a94577F1f4;
        } else if (asset == address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)) {
            return 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        } else if (asset == address(0xdAC17F958D2ee523a2206206994597C13D831ec7)) {
            return 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
        } else if (asset == address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984)) {
            return 0x17756515f112429471F86f98D5052aCB6C47f6ee;
        } else {
            revert("Unsupported asset address");
        }
    }
}