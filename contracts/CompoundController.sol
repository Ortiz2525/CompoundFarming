//SPDX-License-Identifier:MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/compound.sol";
import "./interface/CompoundInterface.sol";

import "hardhat/console.sol";

//supply
//redeem
//borrow
//repay

contract CompoundController is ICompound{
    //Supply token into the Pool
    function supply(address token, address cToken, uint256 _amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), _amount);
        IERC20(token).approve(address(cToken), _amount);
        //If a number is equals zero that means token is minted
        require(CErc20(cToken).mint(_amount) == 0, "mint failed");
    }


    //Enter the market Borrow
    //Before borrowing first supply the token so that you can get ctoken to exchange
    function borrow(address cToken, address _cTokenToBorrow, uint256 borrowAmount) external {
        //Enter the market before supply and borrow
        uint256 _decimals = 18;
        address[] memory cTokens = new address[](1);
        cTokens[0] = cToken;
        uint256[] memory _errors = comptroller.enterMarkets(cTokens);
        require(_errors[0] == 0, "enter market failed");
        //check liquidity
        (uint256 _error, uint256 _liquidity, uint256 _shortfall) = comptroller.getAccountLiquidity(address(this));  
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
        uint256 maxBorrow = (_liquidity * (10**_decimals))/_priceFeed ;
        require(maxBorrow > 0, "Maxborrow = 0");
        // borrow 50% of max borrow
        require(maxBorrow >= borrowAmount, "Maxborrow < borrowAmount");
        //Main Borrow Function
        require(CErc20(_cTokenToBorrow).borrow(borrowAmount) == 0, "Failed");
    }

    function repayBorrow(
        address _tokenBorrowed,
        address _cTokenBorrowed,
        uint256 _amount
    ) external {
        IERC20(_tokenBorrowed).approve(_cTokenBorrowed, _amount);
       console.log(CErc20(_cTokenBorrowed).repayBorrow(_amount));
        require(
            CErc20(_cTokenBorrowed).repayBorrow(_amount) == 0,
            "repay failed"
        ); 
    }

    function getCTokenbalance(address cToken) external view returns (uint256) {
        //It will show the cToken balance of this account
        return CErc20(cToken).balanceOf(address(this));
    }


    //Borrowed balance
    function getBorrowedBalance(address _cTokenBorrowed)
        external
        returns (uint256)
    {
        console.log(
            "Borrowed Balance (cLINK):",
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

    
    //Note: Not a view functions
    function getInfo(address cToken)
        external
        returns (uint256 exchangeRate, uint256 supplyRate)
    {
        //Amount of current Exchange rate from cToken to underlying
        exchangeRate = CErc20(cToken).exchangeRateCurrent();
        console.log("Exchange Rate:", exchangeRate);
        //Amount added to you supply balance this block / Interest Rate
        supplyRate = CErc20(cToken).supplyRatePerBlock();
        console.log("Supply Rate:", supplyRate);
    }

    function estimateBalanceofUnderlying(address cToken) external returns (uint256) {
        uint256 ctokenBal = CErc20(cToken).balanceOf(address(this));
        uint256 exchangeRate = CErc20(cToken).exchangeRateCurrent();
        uint256 decimals = 18; //DAI = 18 decimals
        uint256 CtokenDecimal = 8;
        console.log(
            "Estimated Balance of Underlying:",
            (ctokenBal * exchangeRate) / 10**(18 + decimals - CtokenDecimal)
        );
        return (ctokenBal * exchangeRate) / 10**(18 + decimals - CtokenDecimal);
    }

    //Direct method of getting balance
    function balanceUnderlying(address cToken) external returns (uint256) {
        console.log(
            "Direct Function Balance of cDAI:",
            CErc20(cToken).balanceOfUnderlying(address(this))
        );
        return CErc20(cToken).balanceOfUnderlying(address(this));
    }

    //Redeem function to sell the cToken
    function redeem(address cToken, uint256 _amountCToken) external {
        require( CErc20(cToken).redeem(_amountCToken) == 0, "Process failed");
    }

    //Borrow and Repay
    //Mainnet Comptroller address
    Comptroller public comptroller =
        Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    //chainlink contract mainnet address
    PriceFeed public priceFeed =
        PriceFeed(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);

    //Collateral
    //It will return the percentage value of how much asset the user can borrow against the cToken they hold(in terms of USDC)
    function getCollateral(address cToken) external view returns (uint256) {
        (bool isListed, uint256 colFactor, bool isComped) = comptroller.markets(cToken);
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

}
