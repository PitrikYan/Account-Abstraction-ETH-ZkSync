//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimal is Script {
    MinimalAccount public minimalAccount;

    function run() public {
        deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        minimalAccount = new MinimalAccount(config.entryPoint);
        minimalAccount.transferOwnership(config.account); // now sure if this is neccessary to be here, owner was set to the msg.sender...

        vm.stopBroadcast();
        return (helperConfig, minimalAccount);
    }
}
