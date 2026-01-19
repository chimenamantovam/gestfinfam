// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockToken} from "../src/contracts/MockToken.sol";

contract DeployMockToken is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy do mock DAI
        MockToken mockDai = new MockToken("Mock DAI", "mDAI", 1000 * 10 ** 18);

        console.log("MockToken deployed at:", address(mockDai));

        vm.stopBroadcast();
    }
}
