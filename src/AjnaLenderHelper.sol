// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@ajna-core/interfaces/pool/IPool.sol";
import { IPoolErrors } from '@ajna-core/interfaces/pool/commons/IPoolErrors.sol';
import { 
    _depositFeeRate, 
    _priceAt
}                      from '@ajna-core/libraries/helpers/PoolHelper.sol';
import { Buckets }     from '@ajna-core/libraries/internal/Buckets.sol';
import { Maths }       from "@ajna-core/libraries/internal/Maths.sol";
import { SafeERC20 }   from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 }      from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math }        from '@openzeppelin/contracts/utils/math/Math.sol';

contract AjnaLenderHelper {
    using SafeERC20 for IERC20;

    /**
     *  @notice Smallest amount which would minimize rounding error is, inexplicably, greater than maxAmount specified.
     */
    error RoundedAmountExceededRequestedMaximum();

    /**
     *  @notice Called by lenders to deposit into specified price bucket with protection against exchange rate manipulation.
     *  @param  pool_        Address of the pool in which quote token shall be added.
     *  @param  maxAmount_   The maximum amount of quote token lender wishes to add (`WAD` precision).
     *  @param  index_       The index of the bucket to which the quote tokens will be added.
     *  @param  expiry_      Timestamp after which this transaction will revert, preventing inclusion in a block with unfavorable price.
     *  @return bucketLP_    The amount of `LP` changed for the added quote tokens (`WAD` precision).
     *  @return addedAmount_ The amount of quote token added (`WAD` precision).
     */
    function addQuoteToken(
        address pool_,
        uint256 maxAmount_,
        uint256 index_,
        uint256 expiry_
    ) external returns (uint256 bucketLP_, uint256 addedAmount_) {
        IPool pool = IPool(pool_);
        uint256 amount = _adjustQuantity(index_, maxAmount_, true, pool);

        // perform the deposit
        _transferQuoteTokenFrom(msg.sender, amount, pool);
        _approveForPool(pool, amount);
        (bucketLP_, addedAmount_) = pool.addQuoteToken(amount, index_, expiry_);

        // set LP allowances
        uint256[] memory buckets = new uint256[](1);
        buckets[0] = index_;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = bucketLP_;
        pool.increaseLPAllowance(address(msg.sender), buckets, amounts);

        // return LP to msg.sender
        pool.transferLP(address(this), msg.sender, buckets);
    }

    /**
     *  @notice Called by lenders to move an amount of credit from a specified price bucket to another specified price bucket with protection against exchange rate manipulation.
     *  @param  pool_         Address of the pool in which liquidity shall be moved.
     *  @param  maxAmount_    The maximum amount of quote token to be moved by a lender (`WAD` precision).
     *  @param  fromIndex_    The bucket index from which the quote tokens will be removed.
     *  @param  toIndex_      The bucket index to which the quote tokens will be added.
     *  @param  expiry_       Timestamp after which this transaction will revert, preventing inclusion in a block with unfavorable price.
     *  @return fromBucketRedeemedLP_ The amount of `LP` moved out from bucket (`WAD` precision).
     *  @return toBucketAwardedLP_    The amount of `LP` moved to destination bucket (`WAD` precision).
     *  @return movedAmount_          The amount of quote token moved (`WAD` precision).
     */
    function moveQuoteToken(
        address pool_,
        uint256 maxAmount_,
        uint256 fromIndex_,
        uint256 toIndex_,
        uint256 expiry_
    ) external returns (uint256 fromBucketRedeemedLP_, uint256 toBucketAwardedLP_, uint256 movedAmount_) {
        IPool pool = IPool(pool_);

        // limit the move amount based on deposit available for lender to withdraw after interest accrual
        pool.updateInterest();
        (uint256 lenderLP, ) = pool.lenderInfo(fromIndex_, address(msg.sender));
        uint256 amount = Maths.min(maxAmount_, _lpToQuoteToken(fromIndex_, lenderLP, pool));
        amount = _adjustQuantity(toIndex_, amount, fromIndex_ < toIndex_, pool);

        // transfer lender's LP to helper
        uint256[] memory buckets = new uint256[](1);
        buckets[0] = fromIndex_;
        pool.transferLP(msg.sender, address(this), buckets);

        // move the liquidity
        (fromBucketRedeemedLP_, toBucketAwardedLP_, movedAmount_) = pool.moveQuoteToken(amount, fromIndex_, toIndex_, expiry_);

        // transfer any remaining LP in fromBucket back to lender
        uint256[] memory amounts = new uint256[](1);
        (amounts[0], ) = pool.lenderInfo(fromIndex_, address(this));
        if (amounts[0] != 0) {
            pool.increaseLPAllowance(address(msg.sender), buckets, amounts);
            pool.transferLP(address(this), msg.sender, buckets);
        }

        // transfer LP in toBucket back to lender
        amounts[0] = toBucketAwardedLP_;
        buckets[0] = toIndex_;
        pool.increaseLPAllowance(address(msg.sender), buckets, amounts);
        pool.transferLP(address(this), msg.sender, buckets);
    }

    /**
     *  @notice Called implicitly by addQuoteToken to allow pool to spend the helper's quote token if needed.
     *  @param  pool_              Pool lender wishes to interact with through the helper.
     *  @param  allowanceRequired_ If current allowance lower than this amount, token approval will be performed.
     */
    function _approveForPool(IPool pool_, uint256 allowanceRequired_) internal {
        IERC20 token = IERC20(pool_.quoteTokenAddress());
        if (token.allowance(address(this), address(pool_)) < allowanceRequired_)
        {   // If approval insufficient, run a blanket approval for helper.
            // This saves gas for subsequent lenders using the helper.
            token.approve(address(pool_), type(uint256).max);
        }
    }

    /**
     *  @notice Pulls quote token from lender into this helper contract.
     *  @param  from_   Address of the lender from which quote token shall be transferred.
     *  @param  amount_ Amount of quote token to transfer to helper.
     *  @param  pool_   Pool used to identify quote token scale and address.
     */
    function _transferQuoteTokenFrom(address from_, uint256 amount_, IPool pool_) internal {
        uint256 transferAmount = Maths.ceilDiv(amount_, pool_.quoteTokenScale());
        IERC20(pool_.quoteTokenAddress()).safeTransferFrom(from_, address(this), transferAmount);
    }

    /**
     *  @notice Converts LP balance to quote token amount, limiting by deposit in bucket.
     *  @param  index_    Identifies the bucket.
     *  @param  lpAmount_ Lender's LP balance in the bucket.
     *  @param  pool_     Pool in which the bucket resides.
     *  @return quoteAmount_ The exact amount of quote tokens that can be exchanged for the given `LP`, `WAD` units.
     */
    function _lpToQuoteToken(uint256 index_, uint256 lpAmount_, IPool pool_) internal view returns (uint256 quoteAmount_) {
        (uint256 bucketLP, uint256 bucketCollateral , , uint256 bucketDeposit, ) = pool_.bucketInfo(index_);
        quoteAmount_ = Buckets.lpToQuoteTokens(
            bucketCollateral,
            bucketLP,
            bucketDeposit,
            lpAmount_,
            _priceAt(index_),
            Math.Rounding.Down
        );

        if (quoteAmount_ > bucketDeposit) quoteAmount_ = bucketDeposit;
    }

    /**
     *  @notice Adjusts deposit quantity to minimize rounding error.
     *  @param  index_           Identifies the bucket.
     *  @param  maxAmount_       The maximum amount of quote token to be deposited or moved by a lender (`WAD` precision).
     *  @param  applyDepositFee_ True if moving quote token to a higher-priced bucket, otherwise false.
     *  @param  pool_            Pool in which quote token is being added/moved.
     *  @return amount_ The adjusted amount, in `WAD` units.
     */
    function _adjustQuantity(uint256 index_, uint256 maxAmount_, bool applyDepositFee_, IPool pool_) internal view returns (uint256 amount_) {
        (uint256 bucketLP, uint256 collateral, , uint256 quoteTokens, ) = pool_.bucketInfo(index_);
        if (bucketLP == 0) return maxAmount_;

        /**
            When adding quote token to a bucket, the amount of LP actually recieved is rounded down against the user.
            The user is awarded (qty * lps) / (deposit * WAD + collateral * price) LP tokens.
            So, we should try to ensure (qty * lps) is as close to a multiple of (deposit * WAD + collateral * price) as possible, while exceeding it.
            To choose x<a such that x * b /c close to a multiple of c, set x = [a * b / c * c - 1] / b + 1.  But note that c/b = (deposit * WAD + collateral * price) / lps is the exchange rate.
            An additional wrinkle is introduced by the deposit fee factor, which we first scale the quantity down and then up.
        **/

        uint256 exchangeRate = Buckets.getExchangeRate(collateral, bucketLP, quoteTokens, _priceAt(index_));

        if (applyDepositFee_) {
            (uint256 interestRate, ) = pool_.interestRateInfo();
            uint256 depositFeeFactor = Maths.WAD - _depositFeeRate(interestRate);

            // exact amount that would be passed into quoteTokensToLPs, so want to match it's awarded LPs
            uint256 postFeeMaxAmount = Maths.wmul(maxAmount_, depositFeeFactor);
            // revert if adding quote tokens are not sufficient to get even 1 LP token
            if (postFeeMaxAmount * 1e18 <= exchangeRate) revert IPoolErrors.InsufficientLP();
            uint256 denominator = quoteTokens * Maths.WAD + collateral * _priceAt(index_);

            // calculate the smallest amount we could pass in with same resulting LPs as postFeeMaxAmount
            uint256 minAmountWithSameLPs = ((postFeeMaxAmount * bucketLP * Maths.WAD - 1) / denominator * denominator) / (bucketLP * Maths.WAD) + 1;

            // this should be an amount <= maxAmount that gives minAmountWithSameLPs after wmul with depositFeeFactor
            amount_ = Maths.min(maxAmount_, Maths.ceilWdiv(minAmountWithSameLPs, depositFeeFactor));

            // backup revert... should never happen
            if(Maths.wmul(amount_, depositFeeFactor) < minAmountWithSameLPs) revert RoundedAmountExceededRequestedMaximum();
        } else {
            // revert if adding quote tokens are not sufficient to get even 1 LP token
            if (maxAmount_ * 1e18 <= exchangeRate) revert IPoolErrors.InsufficientLP();
            uint256 denominator = quoteTokens * Maths.WAD + collateral * _priceAt(index_);

            // calculate the smallest amount we could pass in with same resulting LPs as postFeeMaxAmount
            amount_ = ((maxAmount_ * bucketLP * Maths.WAD - 1) / denominator * denominator) / (bucketLP * Maths.WAD) + 1;

            // backup revert... should never happen
            if(maxAmount_ < amount_) revert RoundedAmountExceededRequestedMaximum();
        }
    }
}
