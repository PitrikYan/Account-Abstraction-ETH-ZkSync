//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployMinimal} from "../../script/DeployMinimalAccount.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/mocks/token/ERC20Mock.sol";
import {
    SendPackedUserOp, PackedUserOperation, IEntryPoint, MessageHashUtils
} from "../../script/SendPackedUserOp.s.sol"; // from PackedUserOperation just struct
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    MinimalAccount public minimalAccount;
    HelperConfig public helperConfig;
    ERC20Mock public usdc;
    SendPackedUserOp sendPackedUserOp;

    uint256 constant AMOUNT = 1e18;

    address randomUser = makeAddr("Karel");

    function setUp() public {
        DeployMinimal deployer = new DeployMinimal();
        (helperConfig, minimalAccount) = deployer.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // here we wanna test that msg.sender for some operation will be the minimalaccount
    // we wana make some USDC Mint

    function testOwnerCanExecuteCommand() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSignature("mint(address,uint256)", address(minimalAccount), AMOUNT);

        vm.prank(minimalAccount.owner());
        minimalAccount.execute(destination, value, funcData);

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testOthersCannotExecuteCommand() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSignature("mint(address,uint256)", address(minimalAccount), AMOUNT);

        vm.prank(randomUser);

        vm.expectRevert(MinimalAccount.MinimalAccount__CallerNotEntryPointOrOwner.selector);
        minimalAccount.execute(destination, value, funcData);
    }

    function testRecoverSignedOp() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory destFuncData = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), AMOUNT);

        // here we will call minimalAccount throught entryPoint so we need calldata to call "execute" func
        bytes memory executeCalldata =
            abi.encodeWithSelector(minimalAccount.execute.selector, destination, value, destFuncData);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        PackedUserOperation memory signedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCalldata, config, address(minimalAccount));

        // get UserOp hash in valid format (with EntryPoint address and chainId to prevent replay attacks) AND WITHOUT SIGNATURE AT THE END!
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(signedUserOp);
        bytes32 ethSignedUserOpHash = userOpHash.toEthSignedMessageHash(); // just get the right format for EIP191 signature (to be able to recover)
        address signer = ECDSA.recover(ethSignedUserOpHash, signedUserOp.signature);

        assertEq(minimalAccount.owner(), signer);
    }

    function testValidationOfUserOps() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory destFuncData = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), AMOUNT);

        // here we will call minimalAccount throught entryPoint so we need calldata to call "execute" func
        bytes memory executeCalldata =
            abi.encodeWithSelector(minimalAccount.execute.selector, destination, value, destFuncData);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        PackedUserOperation memory signedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCalldata, config, address(minimalAccount));

        // get UserOp hash in valid format (with EntryPoint address and chainId to prevent replay attacks) AND WITHOUT SIGNATURE AT THE END!
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(signedUserOp);

        // technically this does the same as the previous test, just compare that owner is the signer..
        uint256 missingFundsToRetrieve = 1e18; // we not checking if repay was done correctly (no success check after call)
        vm.prank(config.entryPoint);
        console2.log("Balance of minimal account: ", address(minimalAccount).balance);
        uint256 validationData = minimalAccount.validateUserOp(signedUserOp, userOpHash, missingFundsToRetrieve);
        assertEq(validationData, 0); // 0 means SIG_VALIDATION_SUCCESS
    }

    function testEntryPointCanExecute() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory destFuncData = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), AMOUNT);

        // here we will call minimalAccount throught entryPoint so we need calldata to call "execute" func
        bytes memory executeCalldata =
            abi.encodeWithSelector(minimalAccount.execute.selector, destination, value, destFuncData);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        PackedUserOperation memory signedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCalldata, config, address(minimalAccount));

        // entryPoint could handle multiple transactions for us
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = signedUserOp;

        vm.deal(address(minimalAccount), 1e18);
        vm.prank(randomUser); // anybody can send transaction, as long we signed it

        IEntryPoint(config.entryPoint).handleOps(userOps, payable(randomUser));

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
