// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@ajna-core/interfaces/pool/IPool.sol";
import "@ajna-core/interfaces/pool/IPool.sol";
import {Maths} from "@ajna-core/libraries/internal/Maths.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PRBMathSD59x18} from "@prb-math/contracts/PRBMathSD59x18.sol";
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

contract AjnaRemoveQuote {
    using SafeERC20 for IERC20;

    /**********************************************************************************************
     ** @notice removeQuoteToken function is used to remove quote token liquidity from the pool.
     ** @param  poolAddress Address of the pool in which liquidity shall be moved.
     ** @param  bucketIndex The bucket bucketIndex from which the quote tokens will be removed.
     ** @param  amountToRemove The maximum amount of quote token to be moved by a lender.
     ** @param  minAmountToReceive The minimum amount of quote token to be received by a lender.
     ** @return removedAmount_ The amount of quote token removed.
     ** @return redeemedLP_ The amount of LP redeemed.
     ** @return amountReceived_ The amount of quote token received.
     *********************************************************************************************/
    function removeQuoteToken(
        address poolAddress,
        uint256 bucketIndex,
        uint256 amountToRemove,
        uint256 minAmountToReceive
    ) external returns (uint256 removedAmount_, uint256 redeemedLP_, uint256 amountReceived_) {
        IPool pool = IPool(poolAddress);

        // limit the move amount based on deposit available for lender to withdraw after interest accrual
        pool.updateInterest();

        // transfer lender's LP to helper
        uint256[] memory buckets = new uint256[](1);
        buckets[0] = bucketIndex;
        pool.transferLP(msg.sender, address(this), buckets);

        // remove the liquidity
        (removedAmount_, redeemedLP_) = pool.removeQuoteToken(amountToRemove, bucketIndex);

        // check if the amount received is greater than the minimum amount to receive
        require(removedAmount_ >= minAmountToReceive, "Insufficient amount received");

        // transfer the quote token to the lender
        amountReceived_ = IERC20(pool.quoteTokenAddress()).balanceOf(address(this));
        IERC20(pool.quoteTokenAddress()).transfer(msg.sender, amountReceived_);
    }

    /**********************************************************************************************
     ** @notice removeCollateral function is used to remove collateral token liquidity from the
     **         pool.
     ** @param  poolAddress Address of the pool in which liquidity shall be moved.
     ** @param  bucketIndex The bucket bucketIndex from which the collateral tokens will be
     **          removed.
     ** @param  amountToRemove The maximum amount of collateral token to be moved by a lender.
     ** @param  minAmountToReceive The minimum amount of collateral token to be received by
     **         a lender.
     ** @return removedAmount_ The amount of collateral token removed.
     ** @return redeemedLP_ The amount of LP redeemed.
     ** @return amountReceived_ The amount of collateral token received.
     *********************************************************************************************/
    function removeCollateralToken(
        address poolAddress,
        uint256 bucketIndex,
        uint256 amountToRemove,
        uint256 minAmountToReceive
    ) external returns (uint256 removedAmount_, uint256 redeemedLP_, uint256 amountReceived_) {
        IPool pool = IPool(poolAddress);

        // limit the move amount based on deposit available for lender to withdraw after interest accrual
        pool.updateInterest();

        // transfer lender's LP to helper
        uint256[] memory buckets = new uint256[](1);
        buckets[0] = bucketIndex;
        pool.transferLP(msg.sender, address(this), buckets);


        // remove the liquidity
        (removedAmount_, redeemedLP_) = pool.removeCollateral(amountToRemove, bucketIndex);

        // check if the amount received is greater than the minimum amount to receive
        require(removedAmount_ >= minAmountToReceive, "Insufficient amount removed");

        // transfer the collateral token to the lender
        amountReceived_ = IERC20(pool.collateralAddress()).balanceOf(address(this));
        IERC20(pool.collateralAddress()).transfer(msg.sender, amountReceived_);
    }

    /**********************************************************************************************
     ** @notice Copied from `_priceAt` in PoolHelper contract, made public.
     **         Calculates the price (`WAD` precision) for a given `Fenwick` index.
     ** @dev Reverts with `BucketIndexOutOfBounds` if index exceeds maximum constant.
     ** @dev Uses fixed-point math to get around lack of floating point numbers in `EVM`.
     ** @dev Fenwick index is converted to bucket index.
     ** @dev Fenwick index to bucket index conversion:
     ** @dev   `1.00`      : bucket index `0`,     fenwick index `4156`: `7388-4156-3232=0`.
     ** @dev   `MAX_PRICE` : bucket index `4156`,  fenwick index `0`:    `7388-0-3232=4156`.
     ** @dev   `MIN_PRICE` : bucket index - `3232`, fenwick index `7388`: `7388-7388-3232=-3232`.
     ** @dev `V1`: `price = MIN_PRICE + (FLOAT_STEP * index)`
     ** @dev `V2`: `price = MAX_PRICE * (FLOAT_STEP ** (abs(int256(index - MAX_PRICE_INDEX))));`
     ** @dev `V3 (final)`: `x^y = 2^(y*log_2(x))`
     *********************************************************************************************/
    function getBucketPrice(uint256 bucketIndex) public pure returns (uint256) {
        int256 MAX_BUCKET_INDEX  =  4_156;
        int256 MIN_BUCKET_INDEX  = -3_232;
        int256 FLOAT_STEP_INT = 1.005 * 1e18;

        // Lowest Fenwick index is highest price, so invert the index and offset by highest bucket index.
        int256 index_ = MAX_BUCKET_INDEX - int256(bucketIndex);
        if (index_ < MIN_BUCKET_INDEX || index_ > MAX_BUCKET_INDEX) {
            return 0;
        }

        return uint256(
            PRBMathSD59x18.exp2(
                PRBMathSD59x18.mul(
                    PRBMathSD59x18.fromInt(index_),
                    PRBMathSD59x18.log2(FLOAT_STEP_INT)
                )
            )
        );
    }

     /**********************************************************************************************
     ** @notice Helper function to convert LP tokens to collateral tokens value.
     ** @param  poolAddress Address of the pool 
     ** @param  bucketIndex The bucket index to check
     ** @param  collateralToConvert The amount of collateral to convert
     ** @return The amount of collateral tokens value
     *********************************************************************************************/
    function convertLPToCollateral(
        address poolAddress,
        uint256 bucketIndex,
        uint256 collateralToConvert
    ) public view returns (uint256) {
        IPool pool = IPool(poolAddress);
        
        (
            uint256 lpAccumulated,
            uint256 availableCollateral,,
            uint256 amountOfQuote,
        ) = pool.bucketInfo(bucketIndex);

        uint256 bucketPrice = this.getBucketPrice(bucketIndex);

       return Math.mulDiv(
            amountOfQuote * Maths.WAD + availableCollateral * bucketPrice,
            collateralToConvert,
            lpAccumulated * bucketPrice,
            Math.Rounding.Up
        );
    }
}