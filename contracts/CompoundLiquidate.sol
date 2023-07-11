//SPDX-License-Identifier:MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/compound.sol";
import "hardhat/console.sol";

//supply
//borrow max
//wait feew blocks and let borrowed balance>supplied balance * col factor
//liquidate

contract TestCompoundLiquidate {
    Comptroller public comptroller =
        Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    PriceFeed public priceFeed =
        PriceFeed(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);
    CEth public cTokenSupply;
    IERC20 public tokenBorrow;
    CErc20 public cTokenBorrow;

    constructor(
        address _cTokenSupply,
        address _tokenBorrow,
        address _cTokenBorrow
    ) {
        cTokenSupply = CEth(_cTokenSupply);
        tokenBorrow = IERC20(_tokenBorrow);
        cTokenBorrow = CErc20(_cTokenBorrow);
    }

    receive() external payable {}

    function supply() external payable {
        cTokenSupply.mint{value: msg.value}();
    }

    function getSupplyBalance() external returns (uint256) {
        console.log(
            "balance Of Supply Token:",
            (cTokenSupply.balanceOfUnderlying(address(this))) / 1e18
        );
        return cTokenSupply.balanceOfUnderlying(address(this));
    }

    //Collateral
    //It will return the percentage value of how much asset the user can borrow against the cToken they hold
    function getCollateral() external view returns (uint256) {
        (, uint256 colFactor, ) = comptroller.markets(address(cTokenSupply));
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

    //Enter the market
    function enterMarket() external {
        //Enter the market before supply and borrow
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenSupply);
        uint256[] memory _errors = comptroller.enterMarkets(cTokens);
        require(_errors[0] == 0, "enter market failed");
    }

    function borrow(uint256 _amount) external {
        require(cTokenBorrow.borrow(_amount) == 0, "borrow failed");
    }

    //Borrowed balance
    function getBorrowedBalance() external returns (uint256) {
        console.log(
            "Borrowed Balance (cDAI):",
            (cTokenBorrow.borrowBalanceCurrent(address(this)))
        );
        return cTokenBorrow.borrowBalanceCurrent(address(this));
    }
}

//closefactor
//liquidation incentive
//liquidate

contract CompoundLiquidate {
    Comptroller public comptroller =
        Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    IERC20 public tokenBorrow;
    CErc20 public cTokenBorrow;

    constructor(address _tokenBorrow, address _cTokenBorrow) {
        tokenBorrow = IERC20(_tokenBorrow);
        cTokenBorrow = CErc20(_cTokenBorrow);
    }

    // liquidation incentive
    //Maximum percentage of borrow token can be repaid
    function getCloseFactor() external view returns (uint256) {
        return comptroller.closeFactorMantissa(); //for percentage divided by 1e18
    }

    // liquidation incentive
    //Receive the collateral with discount i.e. Liquidate Incentive
    //The liquidationIncentive, scaled by 1e18, is multiplied by the closed borrow amount from the liquidator
    //to determine how much collateral can be seized.
    function getLiquidationIncentive() external view returns (uint256) {
        return comptroller.liquidationIncentiveMantissa();
    }

    // get amount of collateral to be liquidated
    function getAmountToBeLiquidated(
        address _cTokenBorrowed,
        address _cTokenCollateral,
        uint256 _actualRepayAmount
    ) external view returns (uint256) {
        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */

        (uint256 error, uint256 cTokenCollateralAmount) = comptroller
            .liquidateCalculateSeizeTokens(
                _cTokenBorrowed,
                _cTokenCollateral,
                _actualRepayAmount
            );
        require(error == 0, "error");

        return cTokenCollateralAmount;
    }

    // liquidate
    function liquidate(
        address _borrower,
        uint256 _repayAmount,
        address _cTokenCollateral
    ) external {
        tokenBorrow.transferFrom(msg.sender, address(this), _repayAmount);
        tokenBorrow.approve(address(cTokenBorrow), _repayAmount);

        require(
            cTokenBorrow.liquidateBorrow(
                _borrower,
                _repayAmount,
                _cTokenCollateral
            ) == 0,
            "liquidate failed"
        );
    }

    // get amount liquidated
    // not view function
    function getSupplyBalance(address _cTokenCollateral)
        external
        returns (uint256)
    {
        return CErc20(_cTokenCollateral).balanceOfUnderlying(address(this));
    }
}
