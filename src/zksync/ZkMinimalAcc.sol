//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "@foundry-era/contracts/interfaces/IAccount.sol";
import {Transaction, MemoryTransactionHelper} from "@foundry-era/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "@foundry-era/contracts/libraries/SystemContractsCaller.sol";

import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "@foundry-era/contracts/Constants.sol";
import {INonceHolder} from "@foundry-era/contracts/interfaces/INonceHolder.sol";
import {Utils} from "@foundry-era/contracts/libraries/Utils.sol";

import {MessageHashUtils} from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

contract ZkMinimalAcc is IAccount, Ownable(msg.sender) {
    using MemoryTransactionHelper for Transaction;

    error ZkMinimalAcc__InsufficientFunds();
    error ZkMinimalAcc__NotFromBootloader();
    error ZkMinimalAcc__ExecutionCallFailed();
    error ZkMinimalAcc__NotFromBootloaderOrOwner();
    error ZkMinimalAcc__PaybackToTheBootloaderFailed();
    error ZkMinimalAcc__InvalidTx();

    modifier onlyBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAcc__NotFromBootloader();
        }
        _;
    }

    modifier onlyBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAcc__NotFromBootloaderOrOwner();
        }
        _;
    }

    /**
     * ##############################################
     *              EXTERNAL functions
     * ##############################################
     */
    receive() external payable {}

    /**
     * @notice must increase the nonce (there is NonceHolder contract on zksync), we have to call system contract (foundry.toml -> is-system = true)
     * @notice must validate the transaction (check owner validates tx, but we could validate it cooler random way)
     * @notice check if there is enough money in the account to pay for the tx
     *
     */
    function validateTransaction(
        bytes32, /*_txHash*/
        bytes32, /*_suggestedSignedHash*/
        Transaction calldata _transaction
    ) external payable onlyBootLoader returns (bytes4 magic) {
        return _validateTx(_transaction);
    }

    function executeTransaction(
        bytes32, /*_txHash*/
        bytes32, /*_suggestedSignedHash*/
        Transaction calldata _transaction
    ) external payable onlyBootLoaderOrOwner {
        _executeTransaction(_transaction);
    }

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {
        //first validate tx
        if (_validateTx(_transaction) != ACCOUNT_VALIDATION_SUCCESS_MAGIC) revert ZkMinimalAcc__InvalidTx();
        //then execute
        _executeTransaction(_transaction);
    }

    function payForTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction calldata _transaction)
        external
        payable
    {
        // there is function in memortxhelper for this, currently paying max possible fee
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAcc__PaybackToTheBootloaderFailed();
        }
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction calldata _transaction)
        external
        payable
    {}

    /**
     * ##############################################
     *              INTERNAL functions
     * ##############################################
     */
    function _validateTx(Transaction calldata _transaction) internal returns (bytes4 magic) {
        // Call nonceholder, increase nonce, make system contract call (wtf)
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT), // address(0x8003)
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        // check for fee to pay
        uint256 totalBalanceRequired = _transaction.totalRequiredBalance(); // from library
        if (address(this).balance < totalBalanceRequired) {
            revert ZkMinimalAcc__InsufficientFunds();
        }

        // check the signature and return magic
        bytes32 txHash = _transaction.encodeHash(); // from memorytxhelper library, hashing based on type of tx (this case 712)
        // bytes32 ethConvertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(txHash, _transaction.signature);
        if (signer == owner()) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        //return magic;
    }

    function _executeTransaction(Transaction calldata _transaction) internal {
        address to = address(uint160(_transaction.to)); // tx.to is uint256
        uint128 value = Utils.safeCastToU128(_transaction.value); // maybe we want to use value in system call andd there is value uint128
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            // in case of system contract call (just handle deployer)
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            // in case of a regulat contract call
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZkMinimalAcc__ExecutionCallFailed();
            }
        }
    }
}
