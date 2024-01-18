// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@ajna-core/interfaces/pool/IPool.sol";
import { Maths }  from "@ajna-core/libraries/internal/Maths.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AjnaLenderHelper {
    using SafeERC20 for IERC20;

    function addQuoteToken(
        address pool_,
        uint256 maxAmount_,
        uint256 index_,
        uint256 expiry_
    ) external returns (uint256 bucketLP_, uint256 addedAmount_) {
        uint256 amount_ = maxAmount_;
        IPool pool = IPool(pool_);

        // TODO: validate or adjust amount as appropriate

        // perform the deposit
        _transferQuoteTokenFrom(msg.sender, amount_, pool);
        (bucketLP_, addedAmount_) = pool.addQuoteToken(amount_, index_, expiry_);

        // set LP allowances
        uint256[] memory transferIndexes = new uint256[](1);
        transferIndexes[0] = index_;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = type(uint256).max; //amount_;
        pool.increaseLPAllowance(address(msg.sender), transferIndexes, amounts);

        // return LP to msg.sender
        uint256[] memory bucket = new uint256[](1);
        bucket[0] = index_;
        pool.transferLP(address(this), msg.sender, bucket);
    }

    function _transferQuoteTokenFrom(address from_, uint256 amount_, IPool pool_) internal {
        uint256 transferAmount = Maths.ceilDiv(amount_, pool_.quoteTokenScale());
        IERC20(pool_.quoteTokenAddress()).safeTransferFrom(from_, address(this), transferAmount);
    }

    // TODO: moveQuoteToken
}
