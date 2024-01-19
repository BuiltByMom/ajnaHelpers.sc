// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@ajna-core/interfaces/pool/IPool.sol";
import { _priceAt }  from '@ajna-core/libraries/helpers/PoolHelper.sol';
import { Buckets }   from '@ajna-core/libraries/internal/Buckets.sol';
import { Maths }     from "@ajna-core/libraries/internal/Maths.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 }    from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math }      from '@openzeppelin/contracts/utils/math/Math.sol';

contract AjnaLenderHelper {
    using SafeERC20 for IERC20;

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

        // TODO: adjust amount as appropriate
        uint256 amount = maxAmount_;

        // perform the deposit
        _transferQuoteTokenFrom(msg.sender, amount, pool);
        (bucketLP_, addedAmount_) = pool.addQuoteToken(amount, index_, expiry_);

        // set LP allowances
        uint256[] memory buckets = new uint256[](1);
        buckets[0] = index_;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
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
     *  @return fromBucketLP_ The amount of `LP` moved out from bucket (`WAD` precision).
     *  @return toBucketLP_   The amount of `LP` moved to destination bucket (`WAD` precision).
     *  @return movedAmount_  The amount of quote token moved (`WAD` precision).
     */
    function moveQuoteToken(
        address pool_,
        uint256 maxAmount_,
        uint256 fromIndex_,
        uint256 toIndex_,
        uint256 expiry_
    ) external returns (uint256 fromBucketRedeemedLP_, uint256 toBucketAwardedLP_, uint256 movedAmount_) {
        uint256 amount = maxAmount_;
        IPool pool = IPool(pool_);

        // limit the move amount based on deposit available for lender to withdraw
        pool.updateInterest();
        (uint256 lenderLP, ) = pool.lenderInfo(fromIndex_, address(msg.sender));
        amount = Maths.min(amount, _lpToQuoteToken(fromIndex_, lenderLP, pool));

        // TODO: adjust amount as appropriate based on toIndex_ state

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
     *  @notice Pulls quote token from lender into this helper contract
     */
    function _transferQuoteTokenFrom(address from_, uint256 amount_, IPool pool_) internal {
        uint256 transferAmount = Maths.ceilDiv(amount_, pool_.quoteTokenScale());
        IERC20(pool_.quoteTokenAddress()).safeTransferFrom(from_, address(this), transferAmount);
    }

    /**
     *  @notice Converts LP balance to quote token amount, limiting by deposit in bucket
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
}
