// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import { Test }   from "forge-std/Test.sol";
import { AjnaLenderHelper } from "../src/AjnaLenderHelper.sol";
import { AjnaRemoveQuote } from "../src/RemoveQuote.sol";
import { ERC20Pool }        from '@ajna-core/ERC20Pool.sol';
import { ERC20PoolFactory } from '@ajna-core/ERC20PoolFactory.sol';
import { Token }            from '@ajna-core-test/utils/Tokens.sol';

contract AjnaRemoveQuoteTest is Test {
    error BucketIndexOutOfBounds();

    ERC20PoolFactory internal _poolFactory;
    ERC20Pool        internal _pool;
    Token            internal _ajna;
    Token            internal _collateral;
    Token            internal _quote;
    address          internal _lender;

    AjnaLenderHelper internal _alh;
    AjnaRemoveQuote  internal _arq;

    function setUp() public {
        // create a pool
        _ajna        = new Token("Ajna", "A");
        _collateral  = new Token("Collateral", "C");
        _quote       = new Token("Quote", "Q");
        _poolFactory = new ERC20PoolFactory(address(_ajna));
        _pool        = ERC20Pool(_poolFactory.deployPool(address(_collateral), address(_quote), 0.05 * 1e18));

        // create the helper
        _alh = new AjnaLenderHelper();
        _arq = new AjnaRemoveQuote();

        // configure a lender
        _lender = makeAddr("lender");
        deal(address(_quote), _lender, 100 * 1e18);
        deal(address(_collateral), _lender, 100 * 1e18);
        vm.startPrank(_lender);
        _quote.approve(address(_alh), type(uint256).max);
        _collateral.approve(address(_pool), type(uint256).max);

        // approve the helper as an LP transferror for this EOA (allowance to be set later)
        address[] memory transferors = new address[](1);
        transferors[0] = address(_alh);
        _pool.approveLPTransferors(transferors);
    }

    function testAddAndRemoveQuoteLiquidity() external {
        vm.startPrank(_lender);

        /******************************************************************************************
        ** All this part is linked to the addLiquidity function from the AjnaLenderHelper contract
        ** and not related to the RemoveQuote contract. It is here to setup the test.
        *****************************************************************************************/
        assertEq(_quote.balanceOf(address(_lender)), 100 * 1e18);
        assertEq(_quote.balanceOf(address(_alh)), 0);
        assertEq(_quote.balanceOf(address(_pool)), 0);

        (uint256 bucketLP, uint256 addedAmount) = _alh.addQuoteToken(address(_pool), 95.04 * 1e18, 923, block.timestamp);

        assertEq(bucketLP, 95.035660273972602740 * 1e18);
        assertEq(addedAmount, 95.035660273972602740 * 1e18);
        assertEq(_quote.balanceOf(address(_lender)), 4.96 * 1e18);
        assertEq(_quote.balanceOf(address(_alh)), 0);
        assertEq(_quote.balanceOf(address(_pool)), 95.04 * 1e18);

        (uint256 lpBalance, ) = _pool.lenderInfo(923, address(_lender));
        assertEq(lpBalance, 95.035660273972602740 * 1e18);
        (lpBalance, ) = _pool.lenderInfo(923, address(_alh));
        assertEq(lpBalance, 0);
        uint256 allowance = _pool.lpAllowance(923, _lender, address(_alh));
        assertEq(allowance, 0);


        /******************************************************************************************
        ** This part is linked to the removeQuoteToken function from the AjnaRemoveQuote contract.
        ** We first need to know how much the lender can withdraw from the pool and increate the
        ** allowance for the helper to transfer the LPs.
        ** Then we can call the removeQuoteToken function to remove the quote token from the pool.

        *****************************************************************************************/
        (uint256 amountToWithdraw, ) = _pool.lenderInfo(923, address(_lender));
        uint256[] memory buckets = new uint256[](1);
        buckets[0] = 923;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToWithdraw;
        _pool.increaseLPAllowance(address(_arq), buckets, amounts);

        (uint256 removedAmount, uint256 redeemedLP, uint256 quoteTransfered) = _arq.removeQuoteToken(
            address(_pool), // Address of the pool in which liquidity shall be removed.
            923, // The bucket bucketIndex from which the quote tokens will be removed.
            UINT256_MAX, // The amount of quote token to be removed by a lender.
            amountToWithdraw // The minimum amount of quote token to be received by a lender.
        );

        assertEq(removedAmount, amountToWithdraw);
        assertEq(redeemedLP, 95.035660273972602740 * 1e18);
        assertEq(removedAmount, 95.035660273972602740 * 1e18);
        assertEq(quoteTransfered, 95.035660273972602740 * 1e18);
        assertEq(_quote.balanceOf(address(_alh)), 0);
        assertApproxEqAbs(_quote.balanceOf(address(_lender)), 100*1e18, 0.01 * 1e18); //Some fees are deducted on deposit
    }

    function testAddAndRemoveCollateralLiquidity() external {
        vm.startPrank(_lender);

        /******************************************************************************************
        ** All this part is linked to the addLiquidity function from the AjnaLenderHelper contract
        ** and not related to the RemoveQuote contract. It is here to setup the test.
        *****************************************************************************************/
        assertEq(_collateral.balanceOf(address(_lender)), 100 * 1e18);
        assertEq(_collateral.balanceOf(address(_alh)), 0);
        assertEq(_collateral.balanceOf(address(_pool)), 0);

        uint256 bucketLPDepositedByUser = _pool.addCollateral(95.04 * 1e18, 923, block.timestamp);

        assertEq(_collateral.balanceOf(address(_lender)), 4.96 * 1e18);
        assertEq(_collateral.balanceOf(address(_alh)), 0);
        assertEq(_collateral.balanceOf(address(_pool)), 95.04 * 1e18);

        /******************************************************************************************
        ** This part is linked to the removeQuoteToken function from the AjnaRemoveQuote contract.
        ** We first need to know how much the lender can withdraw from the pool and increate the
        ** allowance for the helper to transfer the LPs.
        ** Then we can call the removeQuoteToken function to remove the quote token from the pool.
        *****************************************************************************************/
        uint256[] memory buckets = new uint256[](1);
        buckets[0] = 923;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = bucketLPDepositedByUser;
        _pool.increaseLPAllowance(address(_arq), buckets, amounts);

        uint256 collateralAvailable = _arq.convertLPToCollateral(address(_pool), 923, bucketLPDepositedByUser);
        (uint256 removedAmount, uint256 redeemedLP, uint256 quoteTransfered) = _arq.removeCollateralToken(
            address(_pool), // Address of the pool in which liquidity shall be removed.
            923, // The bucket bucketIndex from which the quote tokens will be removed.
            collateralAvailable, // The amount of quote token to be removed by a lender.
            collateralAvailable // The minimum amount of quote token to be received by a lender.
        );

        assertEq(redeemedLP, bucketLPDepositedByUser);
        assertEq(removedAmount, collateralAvailable);
        assertEq(removedAmount, 95.04 * 1e18);
        assertEq(quoteTransfered, 95.04 * 1e18);
        assertEq(_collateral.balanceOf(address(_pool)), 0);
        assertApproxEqAbs(_collateral.balanceOf(address(_lender)), 100*1e18, 0.01 * 1e18); //Some fees are deducted on deposit
    }
}
