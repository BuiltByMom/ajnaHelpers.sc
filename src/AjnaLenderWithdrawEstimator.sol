// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@ajna-core/interfaces/pool/IPool.sol";
import { _priceAt, _htp } from '@ajna-core/libraries/helpers/PoolHelper.sol';
import { Maths }    from "@ajna-core/libraries/internal/Maths.sol";
import { PRBMathSD59x18 } from "@prb-math/contracts/PRBMathSD59x18.sol";
import { PRBMathUD60x18 } from "@prb-math/contracts/PRBMathUD60x18.sol";
import { PoolInfoUtils } from "@ajna-core/PoolInfoUtils.sol";

contract AjnaLenderWithdrawEstimator {
    PoolInfoUtils public immutable poolInfoUtils;

    constructor(address poolInfoUtils_){
        poolInfoUtils = PoolInfoUtils(poolInfoUtils_);
    }

    function estimateWithdrawableAmount(
        address pool_,
        uint256 index_,
        address lender_
    ) external returns (uint256 withdrawableAmount_) {
        IPool pool = IPool(pool_);
        
        // Update the interest rate as a static call to make sure the state is updated
        (bool success,) = address(pool).call(abi.encodeWithSignature("updateInterest()"));
        if (!success) {
            return 0;
        }

        // Calculate initial withdrawable amount
        withdrawableAmount_ = _calculateInitialWithdrawableAmount(pool, index_, lender_);
        // Get pool state
        (uint256 poolDebt, , uint256 t0DebtInAuction, ) = pool.debtInfo();

        // Adjust withdrawable amount based on LUP and HTP
        withdrawableAmount_ = _adjustForLupAndHtp(pool, poolDebt, index_, withdrawableAmount_);

        // Adjust withdrawable amount based on liquidations
        withdrawableAmount_ = _adjustForLiquidations(pool, t0DebtInAuction, index_, withdrawableAmount_);
    
        return withdrawableAmount_;
    }

    function _calculateInitialWithdrawableAmount(
        IPool pool,
        uint256 index,
        address lender
    ) internal view returns (uint256) {
        (uint256 bucketLP, uint256 bucketCollateral, , uint256 bucketDeposit, ) = pool.bucketInfo(index);
        (uint256 lenderLP, ) = pool.lenderInfo(index, lender);
        
        uint256 lenderShare = (bucketLP > 0) ? Maths.wdiv(lenderLP, bucketLP) : 0;
        uint256 withdrawableAmount = Maths.wmul(bucketDeposit, lenderShare);
        
        if (bucketCollateral > 0) {
            uint256 bucketPrice = _priceAt(index);
            uint256 collateralValue = Maths.wmul(bucketCollateral, bucketPrice);
            withdrawableAmount += Maths.wmul(collateralValue, lenderShare);
        }
        return Maths.min(withdrawableAmount, bucketDeposit);
    }

    function _adjustForLupAndHtp(
        IPool pool,
        uint256 poolDebt,
        uint256 index,
        uint256 withdrawableAmount
    ) internal view returns (uint256) {
       (,,,uint256 htpIndex,, uint256 lupIndex) = poolInfoUtils.poolPricesInfo(address(pool));

        if (index <= lupIndex && lupIndex <= htpIndex) {
            uint256 newLupIndex = pool.depositIndex(poolDebt + withdrawableAmount);
            if (newLupIndex >= htpIndex) {
                uint256 totalDeposit = pool.depositSize();
                uint256 depositAboveHtp = pool.depositUpToIndex(htpIndex);
                uint256 maxWithdraw = totalDeposit > poolDebt ? totalDeposit - poolDebt : 0;
                
                if (maxWithdraw < withdrawableAmount) {
                    uint256 availableDeposit = depositAboveHtp > poolDebt ? depositAboveHtp - poolDebt : 0;
                    withdrawableAmount = Maths.min(availableDeposit, maxWithdraw);
                }
            }
        }
        return withdrawableAmount;
    }

    function _adjustForLiquidations(
        IPool pool,
        uint256 t0DebtInAuction,
        uint256 index,
        uint256 withdrawableAmount
    ) internal view returns (uint256) {
        if (t0DebtInAuction > 0) {
            (uint256 inflator, ) = pool.inflatorInfo();
            uint256 liquidationDebt = Maths.wmul(t0DebtInAuction, inflator);
            if (index <= pool.depositIndex(liquidationDebt)) {
                return 0;
            }
        }
        return withdrawableAmount;
    }
}