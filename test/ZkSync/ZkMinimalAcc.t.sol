//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ZkMinimalAcc} from "../../src/zksync/ZkMinimalAcc.sol";

import {ERC20Mock} from "@openzeppelin/mocks/token/ERC20Mock.sol";
import {MessageHashUtils} from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "@foundry-era/contracts/Constants.sol";

import {Transaction, MemoryTransactionHelper} from "@foundry-era/contracts/libraries/MemoryTransactionHelper.sol";
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "@foundry-era/contracts/interfaces/IAccount.sol";

contract ZkMinimalAccTest is Test {
    using MemoryTransactionHelper for Transaction;
    using MessageHashUtils for bytes32;

    ZkMinimalAcc minimalAcc;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant ZEROB32 = bytes32(0);
    uint256 constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address constant ANVIL_DEFAULT_SENDER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        minimalAcc = new ZkMinimalAcc();

        minimalAcc.transferOwnership(ANVIL_DEFAULT_SENDER); // to be able to sign tx
        vm.deal(address(minimalAcc), AMOUNT);
        usdc = new ERC20Mock();
    }

    function testOwnerCanExecute() public {
        assertEq(usdc.balanceOf(address(minimalAcc)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeCall(ERC20Mock.mint, (address(minimalAcc), AMOUNT));

        Transaction memory transaction = _createUnsignedTx(minimalAcc.owner(), 0x71, destination, value, funcData);
        // dont care about signature here, because modifier is used which verifies that owner calling this
        vm.prank(minimalAcc.owner());
        minimalAcc.executeTransaction(ZEROB32, ZEROB32, transaction);
        assertEq(usdc.balanceOf(address(minimalAcc)), AMOUNT);
    }

    function testValidateTransaction() public {
        assertEq(usdc.balanceOf(address(minimalAcc)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeCall(ERC20Mock.mint, (address(minimalAcc), AMOUNT));

        Transaction memory transaction = _createUnsignedTx(minimalAcc.owner(), 0x71, destination, value, funcData);

        Transaction memory signedTx = _signTx(transaction);

        vm.prank(BOOTLOADER_FORMAL_ADDRESS); // onlyBootloader modifier used in validatetx
        bytes4 magic = minimalAcc.validateTransaction(ZEROB32, ZEROB32, signedTx);

        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    // ##################### HELPERS #####################

    function _createUnsignedTx(address from, uint8 txType, address to, uint256 value, bytes memory data)
        internal
        view
        returns (Transaction memory unsignedTx)
    {
        unsignedTx = Transaction({
            txType: txType, // type 113 / 0x71
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16888555,
            gasPerPubdataByteLimit: 16888555,
            maxFeePerGas: 16888555,
            maxPriorityFeePerGas: 16888555,
            paymaster: 0,
            nonce: vm.getNonce(address(minimalAcc)),
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: new bytes32[](0),
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }

    function _signTx(Transaction memory transaction) internal view returns (Transaction memory) {
        bytes32 txHash = transaction.encodeHash();
        //bytes32 digest = txHash.toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ANVIL_DEFAULT_KEY, /*digest*/ txHash);
        transaction.signature = abi.encodePacked(r, s, v);

        return transaction; // returns signed tx
    }
}
