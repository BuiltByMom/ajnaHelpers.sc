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
        vm.startPrank(_lender);
        _quote.approve(address(_alh),  type(uint256).max);

        // approve the helper as an LP transferror for this EOA (allowance to be set later)
        address[] memory transferors = new address[](2);
        transferors[0] = address(_alh);
        transferors[1] = address(_arq);
        _pool.approveLPTransferors(transferors);
    }

    function testAddLiquidity() external {
        vm.startPrank(_lender);

        // check starting balances
        console.log("-----------------------------------------------------------------------------------------");
        console.log("------------------------------------- INITIAL STATE -------------------------------------");
        console.log("-----------------------------------------------------------------------------------------");
        console.log("_quote.balanceOf(address(_lender)) :", _quote.balanceOf(address(_lender)));
        console.log("_quote.balanceOf(address(_alh))    :", _quote.balanceOf(address(_alh)));
        console.log("_quote.balanceOf(address(_pool))   :", _quote.balanceOf(address(_pool)));
        assertEq(_quote.balanceOf(address(_lender)), 100 * 1e18);
        assertEq(_quote.balanceOf(address(_alh)), 0);
        assertEq(_quote.balanceOf(address(_pool)), 0);

        // deposit through helper
        (uint256 bucketLP, uint256 addedAmount) = _alh.addQuoteToken(address(_pool), 95.04 * 1e18, 923, block.timestamp);
        assertEq(bucketLP, 95.035660273972602740 * 1e18);
        assertEq(addedAmount, 95.035660273972602740 * 1e18);

        console.log("-----------------------------------------------------------------------------------------");
        console.log("--------------------------------- AFTER ADD QUOTE TOKEN ---------------------------------");
        console.log("-----------------------------------------------------------------------------------------");
        console.log("bucketLP                           :", bucketLP);
        console.log("addedAmount                        :", addedAmount);
        console.log("_quote.balanceOf(address(_lender)) :", _quote.balanceOf(address(_lender)));
        console.log("_quote.balanceOf(address(_alh))    :", _quote.balanceOf(address(_alh)));
        console.log("_quote.balanceOf(address(_pool))   :", _quote.balanceOf(address(_pool)));
        assertEq(_quote.balanceOf(address(_lender)), 4.96 * 1e18);
        assertEq(_quote.balanceOf(address(_alh)), 0);
        assertEq(_quote.balanceOf(address(_pool)), 95.04 * 1e18);
        (uint256 lpBalance, ) = _pool.lenderInfo(923, address(_lender));
        assertEq(lpBalance, 95.035660273972602740 * 1e18);
        (lpBalance, ) = _pool.lenderInfo(923, address(_alh));
        assertEq(lpBalance, 0);
        uint256 allowance = _pool.lpAllowance(923, _lender, address(_alh));
        assertEq(allowance, 0);


        (uint256 amountToWithdraw, ) = _pool.lenderInfo(923, address(_lender));
        uint256[] memory buckets = new uint256[](1);
        buckets[0] = 923;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToWithdraw;
        _pool.increaseLPAllowance(address(_arq), buckets, amounts);

        (uint256 removedAmount, uint256 redeemedLP, uint256 quoteTransfered) = _arq.removeQuoteToken(address(_pool), UINT256_MAX, amountToWithdraw, 923);
        assertEq(removedAmount, amountToWithdraw);
        assertEq(redeemedLP, 95.035660273972602740 * 1e18);
        console.log("-----------------------------------------------------------------------------------------");
        console.log("--------------------------------- AFTER REM QUOTE TOKEN ---------------------------------");
        console.log("-----------------------------------------------------------------------------------------");
        console.log("removedAmount                      :", removedAmount);
        console.log("redeemedLP                         :", redeemedLP);
        console.log("quoteTransfered                    :", quoteTransfered);
        console.log("_quote.balanceOf(address(_lender)) :", _quote.balanceOf(address(_lender)));
        console.log("_quote.balanceOf(address(_alh))    :", _quote.balanceOf(address(_alh)));
        console.log("_quote.balanceOf(address(_pool))   :", _quote.balanceOf(address(_pool)));


    }
}
