// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/compound.sol";

import "hardhat/console.sol";

//supply 
//redeem
//borrow
//repay

contract CompoundETH {
    CEth public cToken;

    constructor(address _cToken) {
        cToken = CEth(_cToken);
    }

    receive() external payable {}

    function supply() external payable {
        cToken.mint{value: msg.value}();
    }

    function getCTokenBalance() external view returns (uint256) {
        return cToken.balanceOf(address(this));
    }

    // not view function
    function getInfo()
        external
        returns (uint256 exchangeRate, uint256 supplyRate)
    {
        // Amount of current exchange rate from cToken to underlying
        exchangeRate = cToken.exchangeRateCurrent();
        // Amount added to you supply balance this block
        supplyRate = cToken.supplyRatePerBlock();
    }

    // not view function
    function estimateBalanceOfUnderlying() external returns (uint256) {
        uint256 cTokenBal = cToken.balanceOf(address(this));
        uint256 exchangeRate = cToken.exchangeRateCurrent();
        uint256 decimals = 18; // DAI = 18 decimals
        uint256 cTokenDecimals = 8;

        return
            (cTokenBal * exchangeRate) / 10**(18 + decimals - cTokenDecimals);
    }

    // not view function
    function balanceOfUnderlying() external returns (uint256) {
        console.log(
            "balance Of cToken",
            cToken.balanceOfUnderlying(address(this)) / 1e18
        );
        return cToken.balanceOfUnderlying(address(this));
    }

    function redeem(uint256 _cTokenAmount) external {
        require(cToken.redeem(_cTokenAmount) == 0, "redeem failed");
        // cToken.redeemUnderlying(underlying amount);
    }

    //Borrow and Repay
    //Mainnet Comptroller address
    Comptroller public comptroller =
        Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    //chainlink contract mainnet address
    PriceFeed public priceFeed =
        PriceFeed(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);

    //Collateral
    //It will return the percentage value of how much asset the user can borrow against the cToken they hold
    function getCollateral() external view returns (uint256) {
        (bool isListed, uint256 colFactor, bool isComped) = comptroller.markets(
            address(cToken)
        );
        require(isListed, "Token is not listed");
        require(isComped, "Not eligible"); //whether or not the suppliers and borrowers of an asset are eligible to receive "COMP"
        return colFactor; //divide this 1e18 to get value in percentage
    }

    //This function return, how much token user can borrow and it depends on the collateral factor
    // sum of (supplied balance of market entered * col factor) - borrowed
    function getAccountLiquidity() external view returns (uint256, uint256) {
        (uint256 _error, uint256 _liquidity, uint256 _shortfall) = comptroller
            .getAccountLiquidity(address(this));
        require(
            _error == 0,
            "Sender either not authorized/Some internal factor is invalid"
        );
        return (_liquidity, _shortfall);
    }

    //Get the price in USD with 6 decimal precision
    function getPriceFeed(address _cToken) external view returns (uint256) {
        //scaled by 1e18
        return priceFeed.getUnderlyingPrice(_cToken);
    }

    //Enter the market Borrow
    //Before borrowing first supply the token so that you can get ctoken to exchange
    function borrow(address _cTokenToBorrow, uint256 _decimals) external {
        //Enter the market before supply and borrow
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);
        uint256[] memory _errors = comptroller.enterMarkets(cTokens);
        require(_errors[0] == 0, "enter market failed");
        //check liquidity
        (uint256 _error, uint256 _liquidity, uint256 _shortfall) = comptroller
            .getAccountLiquidity(address(this));
        require(
            _error == 0,
            "Sender either not authorized/Some internal factor is invalid"
        );
        require(_shortfall == 0, "Borrowed over limit"); //The account is currently below the collateral requirement
        require(_liquidity > 0, "Can't borrow");
        //calculate Max borrow
        uint256 _priceFeed = priceFeed.getUnderlyingPrice(_cTokenToBorrow);
        // liquidity - USD scaled up by 1e18
        // price - USD scaled up by 1e18
        // decimals - decimals of token to borrow
        uint256 maxBorrow = (_liquidity * (10**_decimals)) / _priceFeed;
        require(maxBorrow > 0, "Maxborrow = 0");
        // borrow 50% of max borrow
        uint256 amount = (maxBorrow * 50) / 100;
        //Main Borrow Function
        require(CErc20(_cTokenToBorrow).borrow(amount) == 0, "Failed");
    }

    //Borrowed balance
    function getBorrowedBalance(address _cTokenBorrowed)
        external
        returns (uint256)
    {
        console.log(
            "Borrowed Balance (cDAI):",
            CErc20(_cTokenBorrowed).borrowBalanceCurrent(address(this))
        );
        return CErc20(_cTokenBorrowed).borrowBalanceCurrent(address(this));
    }

    function getBorrowedRatePerBlock(address _cTokenBorrowed)
        external
        view
        returns (uint256)
    {
        return CErc20(_cTokenBorrowed).borrowRatePerBlock();
    }

    //repay Borrowed Token
    function repay(
        address _tokenBorrowed,
        address _cTokenBorrowed,
        uint256 _amount
    ) external {
        IERC20(_tokenBorrowed).approve(_cTokenBorrowed, _amount);
        require(
            CErc20(_cTokenBorrowed).repayBorrow(_amount) == 0,
            "repay failed"
        );
    }
}
