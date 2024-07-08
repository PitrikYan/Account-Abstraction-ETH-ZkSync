//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol"; // just because of struct definition
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {
        /*

        // Setup
        HelperConfig helperConfig = new HelperConfig();
        address dest = helperConfig.getConfig().usdc; // arbitrum mainnet USDC address
        uint256 value = 0;
        address minimalAccountAddress = DevOpsTools.get_most_recent_deployment("MinimalAccount", block.chainid);

        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, RANDOM_APPROVER, 1e18);
        bytes memory executeCalldata =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory userOp =
            generateSignedUserOperation(executeCalldata, helperConfig.getConfig(), minimalAccountAddress);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        // Send transaction
        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
        vm.stopBroadcast();

        */
    }

    function generateSignedUserOperation(
        bytes memory _callData, /*address _sender*/
        HelperConfig.NetworkConfig memory _config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        uint256 nonce = vm.getNonce( /*_sender*/ minimalAccount) - 1; // foundry help us to get nonce of an address  FOR SOME REASON HAVE TO SUBTRACT 1
        // generate struct
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(_callData, /*_sender*/ minimalAccount, nonce);

        // get UserOp hash in valid format (with EntryPoint address and chainId to prevent replay attacks) AND WITHOUT SIGNATURE AT THE END!
        bytes32 userOpHash = IEntryPoint(_config.entryPoint).getUserOpHash(userOp);

        bytes32 digest = userOpHash.toEthSignedMessageHash(); // hash with prefix

        uint8 v;
        bytes32 r;
        bytes32 s;

        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(_config.account, digest);
        }

        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(_config.account, digest);
        userOp.signature = abi.encodePacked(r, s, v); // adding signature to the struct
        return userOp;
    }

    function _generateUnsignedUserOperation(bytes memory _callData, address _sender, uint256 _nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verififcationGasLimit = 16888555;
        uint128 callGasLimit = verififcationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 naxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: _sender,
            nonce: _nonce,
            initCode: hex"",
            callData: _callData,
            accountGasLimits: bytes32(uint256(verififcationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verififcationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | naxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
