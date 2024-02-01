// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2 }   from "forge-std/Test.sol";
import { AjnaLenderHelper } from "../src/AjnaLenderHelper.sol";
import { ERC20Pool }        from '@ajna-core/ERC20Pool.sol';
import { ERC20PoolFactory } from '@ajna-core/ERC20PoolFactory.sol';
import { SafeERC20 }        from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 }           from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LenderHelperInteractionsTest is Test {
    using SafeERC20 for IERC20;

    ERC20PoolFactory internal _poolFactory;
    ERC20Pool        internal _pool;
    IERC20           internal _ajna;
    address          internal _lender;

    IERC20           internal _quote;
    IERC20           internal _collateral;

    address          internal _weth;
    address          internal _usdt;

    AjnaLenderHelper internal _alh;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        _ajna = IERC20(address(0x9a96ec9B57Fb64FbC60B423d1f4da7691Bd35079));

        _weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        _usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);

        _lender = address(0xD0dCd5D96b1353b95cF04B76a96777D410D2Ac2a);

        // configure tokens
        _quote      = IERC20(address(_usdt));
        _collateral = IERC20(address(_weth));

        // create a pool
        _poolFactory = new ERC20PoolFactory(address(_ajna));
        _pool        = ERC20Pool(_poolFactory.deployPool(address(_weth), address(_usdt), 0.05 * 1e18));

        // configure a lender
        _lender = makeAddr("lender");
        deal(address(_quote), _lender, 100 * 1e6);
        assertEq(_quote.balanceOf(address(_lender)), 100 * 1e6);

        // create the helper
        _alh = new AjnaLenderHelper();

        // approve the helper as an LP transferror for this EOA (allowance to be set later)
        changePrank(_lender);
        address[] memory transferors = new address[](1);
        transferors[0] = address(_alh);
        _pool.approveLPTransferors(transferors);

    }

    function testAddQtUsdtApproval() public {

        changePrank(_lender);

        // lender approves _alh to spend USDT
        // _usdt.approve does not return a boolean causing an EVM revert when the contract is wrapped in OZ's SafeERC20
        // we use safeIncreaseAllowance instead
        IERC20(address(_usdt)).safeIncreaseAllowance(address(_alh), type(uint256).max);

        (uint256 bucketLP_, uint256 amount_) = _alh.addQuoteToken(address(_pool), 100 * 1e18, 3024, block.timestamp + 1);
        
        assertEq(bucketLP_, 99.995433789954337900 * 1e18);
        assertEq(amount_,   99.995433789954337900 * 1e18);

        // confirm lender has LP in the appropriate buckets and helper has no LP
        (uint256 lpBalance, ) = _pool.lenderInfo(3024, address(_lender));
        assertEq(lpBalance, 99.995433789954337900 * 1e18);
        (lpBalance, ) = _pool.lenderInfo(3024, address(_alh));
        assertEq(lpBalance, 0);
    }
}