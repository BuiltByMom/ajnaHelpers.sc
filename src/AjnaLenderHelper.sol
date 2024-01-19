// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@ajna-core/interfaces/pool/IPool.sol";
import { Maths }     from "@ajna-core/libraries/internal/Maths.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 }    from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AjnaLenderHelper {
    using SafeERC20 for IERC20;

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

    function moveQuoteToken(
        address pool_,
        uint256 maxAmount_,
        uint256 fromIndex_,
        uint256 toIndex_,
        uint256 expiry_
    ) external returns (uint256 fromBucketRedeemedLP_, uint256 toBucketAwardedLP_, uint256 movedAmount_) {
        uint256 amount = maxAmount_;
        IPool pool = IPool(pool_);

        // TODO: adjust amount as appropriate based on toIndex_ state

        // transfer lender's LP to helper
        uint256[] memory buckets = new uint256[](1);
        buckets[0] = fromIndex_;
        pool.transferLP(msg.sender, address(this), buckets);

        // move the liquidity
        (fromBucketRedeemedLP_, toBucketAwardedLP_, movedAmount_) = pool.moveQuoteToken(amount, fromIndex_, toIndex_, expiry_);

        // transfer remaining LP in fromBucket back to lender
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

    function _transferQuoteTokenFrom(address from_, uint256 amount_, IPool pool_) internal {
        uint256 transferAmount = Maths.ceilDiv(amount_, pool_.quoteTokenScale());
        IERC20(pool_.quoteTokenAddress()).safeTransferFrom(from_, address(this), transferAmount);
    }
}
