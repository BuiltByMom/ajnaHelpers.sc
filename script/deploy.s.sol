// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from "forge-std/Script.sol";
import { AjnaLenderHelper } from 'src/AjnaLenderHelper.sol';

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        AjnaLenderHelper alh = new AjnaLenderHelper();
        vm.stopBroadcast();

        console2.log("Deployed to %s", address(alh));
    }
}
