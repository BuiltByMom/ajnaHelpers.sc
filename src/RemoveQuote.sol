// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@ajna-core/interfaces/pool/IPool.sol";
import { Maths }       from "@ajna-core/libraries/internal/Maths.sol";
import { SafeERC20 }   from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 }      from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AjnaRemoveQuote {
    using SafeERC20 for IERC20;

    /**
     *  @notice Called by lenders to move an amount of credit from a specified price bucket to another specified price bucket with protection against exchange rate manipulation.
     *  @param  poolAddress Address of the pool in which liquidity shall be moved.
     *  @param  amountToRemove The maximum amount of quote token to be moved by a lender (`WAD` precision).
     *  @param  minAmountToReceive The minimum amount of quote token to be received by a lender (`WAD` precision).
     *  @param  bucketIndex The bucket bucketIndex from which the quote tokens will be removed.
     *  @return removedAmount_ The amount of quote token removed (`WAD` precision).
     *  @return redeemedLP_ The amount of LP redeemed (`WAD` precision).
     *  @return amountReceived_ The amount of quote token received (`WAD` precision).
     */
    function removeQuoteToken(
        address poolAddress,
        uint256 amountToRemove,
        uint256 minAmountToReceive,
        uint256 bucketIndex
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

        require(removedAmount_ >= minAmountToReceive, "Insufficient amount received");

        amountReceived_ = IERC20(pool.quoteTokenAddress()).balanceOf(address(this));
        IERC20(pool.quoteTokenAddress()).transfer(msg.sender, amountReceived_);
    }
}