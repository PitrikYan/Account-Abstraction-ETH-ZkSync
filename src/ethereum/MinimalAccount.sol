//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    error MinimalAccount__CallerNotEntryPoint();
    error MinimalAccount__CallerNotEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

    IEntryPoint private immutable i_entryPoint;

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    modifier onlyEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__CallerNotEntryPoint();
        }
        _;
    }

    modifier onlyEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__CallerNotEntryPointOrOwner();
        }
        _;
    }
    // ########### EXTERNAL FUNCTIONS ############

    // this is the function what entryPoint contract will call
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        // _validateNonce();    should be also done

        // payaback to msg.sender whatever the transaction costs them
        _payPrefund(missingAccountFunds);
    }

    // to be able to call something
    // it could be executed through the entryPoint or through the owner
    function execute(address destination, uint256 amount, bytes calldata functionData) external onlyEntryPointOrOwner {
        (bool success, bytes memory result) = destination.call{value: amount}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    // ########### INTERNAL FUNCTIONS ############

    // we could use any signature we want! And then here we have to validate it..
    // here we choose to use signature of the owner of this contract
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash); // just get the right format for EIP191 signature (to be able to recover)
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED; //returns 1
        } else {
            return SIG_VALIDATION_SUCCESS; // returns 0
        }
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds}("");
        }
    }

    // ########### GETTERS ############

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
