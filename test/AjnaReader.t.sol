// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { AjnaReader } from "../src/AjnaReader.sol";
import { ERC20Pool } from '@ajna-core/ERC20Pool.sol';

contract AjnaReaderTest is Test {
    AjnaReader public _alh;

    function setUp() public {
        address poolInfoUtils = 0x6c5c7fD98415168ada1930d44447790959097482;
        _alh = new AjnaReader(poolInfoUtils);
    }

    function testAjnaReaderWithLUP() public {
        address lender = address(0x8596d963e0DEBCa873A56FbDd2C9d119Aa0eB443);
        uint256 index = 2771;
        ERC20Pool pool = ERC20Pool(0xe8dCc8FbAb00cF7911944dE5f9080Ecd9f25d3A9);

        vm.startPrank(lender);

        // Get the initial user LP balance
        (uint256 lpBalance_, ) = pool.lenderInfo(index, lender);
        console.log("lpBalance for user: %s", lpBalance_);

        // Get the amount we can withdraw for the user
        (bool success, bytes memory result) = address(_alh).call(abi.encodeWithSignature("estimateWithdrawableAmount(address,uint256,address)", address(pool), index, lender));
        uint256 estimate = abi.decode(result, (uint256));
        console.log("amount available to withdraw: %s", estimate);

        // Withdraw the amount and log the new balance
        (uint256 removedAmount, uint256 redeemedAmount) = pool.removeQuoteToken(estimate, index);
        (lpBalance_, ) = pool.lenderInfo(index, lender); 
        console.log("amount removed: %s", removedAmount);
        console.log("amount redeemed: %s", redeemedAmount);
        console.log("lpBalance for user: %s", lpBalance_);
        
        // Make sure the user can't withdraw more
        (success, result) = address(_alh).call(abi.encodeWithSignature("estimateWithdrawableAmount(address,uint256,address)", address(pool), index, lender));
        console.log("New amount available to withdraw: %s", abi.decode(result, (uint256)));
        assertEq(abi.decode(result, (uint256)), 0);
    }

    function testAjnaReaderWithAll() public {
        address lender = address(0x8596d963e0DEBCa873A56FbDd2C9d119Aa0eB443);
        uint256 index = 2771;
        ERC20Pool pool = ERC20Pool(0xa390765fB18EdCBC15dc9e2d56D9FC33c1a3FAcb);
        vm.startPrank(lender);

        // Get the initial user LP balance
        (uint256 lpBalance_, ) = pool.lenderInfo(index, lender);
        console.log("lpBalance for user: %s", lpBalance_);

        // Get the amount we can withdraw for the user
        (bool success, bytes memory result) = address(_alh).call(abi.encodeWithSignature("estimateWithdrawableAmount(address,uint256,address)", address(pool), index, lender));
        uint256 estimate = abi.decode(result, (uint256));
        console.log("amount available to withdraw: %s", estimate);

        // Withdraw the amount and log the new balance
        (uint256 removedAmount, uint256 redeemedAmount) = pool.removeQuoteToken(estimate, index);
        (lpBalance_, ) = pool.lenderInfo(index, lender); 
        console.log("amount removed: %s", removedAmount);
        console.log("amount redeemed: %s", redeemedAmount);
        console.log("lpBalance for user: %s", lpBalance_);
        
        // Make sure the user can't withdraw more
        (success, result) = address(_alh).call(abi.encodeWithSignature("estimateWithdrawableAmount(address,uint256,address)", address(pool), index, lender));
        console.log("New amount available to withdraw: %s", abi.decode(result, (uint256)));
        assertEq(abi.decode(result, (uint256)), 0);
    }

    function testAjnaReaderWithActiveLiquidation() public {
        address lender = address(0x8596d963e0DEBCa873A56FbDd2C9d119Aa0eB443);
        uint256 index = 2770;
        ERC20Pool pool = ERC20Pool(0xa390765fB18EdCBC15dc9e2d56D9FC33c1a3FAcb);
        vm.startPrank(lender);

        // Get the initial user LP balance
        (uint256 lpBalance_, ) = pool.lenderInfo(index, lender);
        console.log("lpBalance for user: %s", lpBalance_);

        // Get the amount we can withdraw for the user
        (bool success, bytes memory result) = address(_alh).call(abi.encodeWithSignature("estimateWithdrawableAmount(address,uint256,address)", address(pool), index, lender));
        uint256 estimate = abi.decode(result, (uint256));
        console.log("amount available to withdraw: %s", estimate);
        assertEq(estimate, 0);
    }

    function testAjnaReaderWithLUP2() public {
        address lender = address(0xeeDC2EE00730314b7d7ddBf7d19e81FB7E5176CA);
        uint256 index = 2771;
        ERC20Pool pool = ERC20Pool(0xe8dCc8FbAb00cF7911944dE5f9080Ecd9f25d3A9);
        vm.startPrank(lender);


        // Get the initial user LP balance
        (uint256 lpBalance_, ) = pool.lenderInfo(index, lender);
        console.log("lpBalance for user: %s", lpBalance_);

        // Get the amount we can withdraw for the user
        (bool success, bytes memory result) = address(_alh).call(abi.encodeWithSignature("estimateWithdrawableAmount(address,uint256,address)", address(pool), index, lender));
        uint256 estimate = abi.decode(result, (uint256));
        console.log("amount available to withdraw: %s", estimate);

        // Withdraw the amount and log the new balance
        (uint256 removedAmount, uint256 redeemedAmount) = pool.removeQuoteToken(estimate, index);
        (lpBalance_, ) = pool.lenderInfo(index, lender); 
        console.log("amount removed: %s", removedAmount);
        console.log("amount redeemed: %s", redeemedAmount);
        console.log("lpBalance for user: %s", lpBalance_);
        
        // Make sure the user can't withdraw more
        (success, result) = address(_alh).call(abi.encodeWithSignature("estimateWithdrawableAmount(address,uint256,address)", address(pool), index, lender));
        console.log("New amount available to withdraw: %s", abi.decode(result, (uint256)));
        assertEq(abi.decode(result, (uint256)), 0);
    }

    function testInterestRate() public {
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        ERC20Pool pool = ERC20Pool(0x0F0027d20468D1F028FF30466c62686F5dC58733);

        (uint256 interest, uint256 updateTime) = pool.interestRateInfo();
        console.log("previous interest rate: %s at %s", interest, updateTime);

        (, bytes memory result) = address(_alh).call(abi.encodeWithSignature("getInterestRate(address)", address(pool)));
        uint256 estimate = abi.decode(result, (uint256));
        console.log("expected interest rate: %s", estimate);
    }

}