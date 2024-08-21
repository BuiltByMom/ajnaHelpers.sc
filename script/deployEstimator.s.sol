// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from "forge-std/Script.sol";
import { AjnaLenderWithdrawEstimator } from 'src/AjnaLenderWithdrawEstimator.sol';

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address poolInfoUtils = 0x6c5c7fD98415168ada1930d44447790959097482;
        AjnaLenderWithdrawEstimator alh = new AjnaLenderWithdrawEstimator(poolInfoUtils);
        vm.stopBroadcast();

        console2.log("Deployed to %s", address(alh));
    }
}
