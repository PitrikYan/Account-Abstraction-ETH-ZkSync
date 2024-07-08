## Account Abstraction

**On ETH & ZkSync**

Allowing EoA to behave like smart contracts.
Validation of the transaction could be custom logic (not just by PK signature).

You can use Paymaster as the sponsors for the transaction fees.
It is possible to pay fees not just in native token, but also with ERC-20 tokens.
We are not using paymasters in this codebase.

Project consists of:

- **ETH Account abstraction**: There it is not natively build-in, so we need to use "alt-mempools" and EntryPoint contract
- **AA on ZkSync**: Native part of L2

## Documentation

https://eips.ethereum.org/EIPS/eip-4337

https://docs.zksync.io/build/developer-reference/ethereum-differences/native-vs-eip4337

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Deploy and send TX

Deploying to ZkSync is a little bit tricky right now..
Requirements and procedures as explained here:

https://github.com/Cyfrin/minimal-account-abstraction?tab=readme-ov-file#getting-started
