// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import { AjnaLenderHelper } from "../src/AjnaLenderHelper.sol";
import { ERC20Pool }           from '@ajna-core/ERC20Pool.sol';
import { ERC20PoolFactory }    from '@ajna-core/ERC20PoolFactory.sol';
import { Token }               from '@ajna-core-test/utils/Tokens.sol';

contract AjnaLenderHelperTest is Test {
    ERC20PoolFactory internal _poolFactory;
    ERC20Pool        internal _pool;
    Token            internal _ajna;
    Token            internal _collateral;
    Token            internal _quote;
    address          internal _lender;

    AjnaLenderHelper internal _alh;

    function setUp() public {
        // create a pool
        _ajna        = new Token("Ajna", "A");
        _collateral  = new Token("Collateral", "C");
        _quote       = new Token("Quote", "Q");
        _poolFactory = new ERC20PoolFactory(address(_ajna));
        _pool        = ERC20Pool(_poolFactory.deployPool(address(_collateral), address(_quote), 0.05 * 1e18));

        // create the helper
        _alh = new AjnaLenderHelper();
        changePrank(address(_alh));
        _quote.approve(address(_pool), type(uint256).max);

        // configure a lender
        _lender = makeAddr("lender");
        deal(address(_quote), _lender, 100 * 1e18);
        changePrank(_lender);
        _quote.approve(address(_pool), type(uint256).max);
        _quote.approve(address(_alh),  type(uint256).max);

        // TODO: discuss moving approvals into the helper itself
        address[] memory transferors = new address[](1);
        transferors[0] = address(_alh);
        _pool.approveLPTransferors(transferors);
    }

    function testDeposit() external {
        changePrank(_lender);

        // check starting balances
        assertEq(_quote.balanceOf(address(_lender)), 100 * 1e18);
        assertEq(_quote.balanceOf(address(_alh)), 0);
        assertEq(_quote.balanceOf(address(_pool)), 0);

        // deposit through helper
        (uint256 bucketLP, uint256 addedAmount) = _alh.addQuoteToken(address(_pool), 95.04 * 1e18, 923, block.timestamp);
        assertEq(bucketLP, 95.035660273972602740 * 1e18);
        assertEq(addedAmount, 95.035660273972602740 * 1e18);

        // confirm tokens are in expected places
        assertEq(_quote.balanceOf(address(_lender)), 4.96 * 1e18);
        assertEq(_quote.balanceOf(address(_alh)), 0);
        assertEq(_quote.balanceOf(address(_pool)), 95.04 * 1e18);

        // confirm lender received LP in the bucket
        (uint256 lpBalance, ) = _pool.lenderInfo(923, address(_lender));
        assertEq(lpBalance, 95.035660273972602740 * 1e18);
    }
}