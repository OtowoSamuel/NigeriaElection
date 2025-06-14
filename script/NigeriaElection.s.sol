// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NigeriaElection} from "../src/NigeriaElection.sol";

contract NigeriaElectionScript is Script {
    NigeriaElection public election;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        election = new NigeriaElection();

        console.log("NigeriaElection deployed at:", address(election));

        vm.stopBroadcast();
    }
}
