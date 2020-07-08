# Account Abstraction Playground
This repo is part of the Quilt team's R&D effort on the feasibility of bringing account abstraction (AA) to eth1.
At the core of this effort is our fork of go-ethereum that implements a basic version of AA as [outlined by Vitalik](https://ethereum-magicians.org/t/implementing-account-abstraction-as-part-of-eth1-x/4020) earlier this year.
We are currently in the process of collecting metrics and will be writing a comprehensive overview of our work so far and our future goals once that is done.
In the meantime, this repo aims to enable anyone interested to already explore our current AA MVP implementation.
It tracks the latest stable version of our go-ethereum fork and as such is subject to change as we continue development.
Note that at the current time we do not yet have a position on bringing AA to mainnet, but will communicate our assessment of AA feasibility as part of our upcoming writeup.

The following instructions are written for macOS, but should be similar for most Linux systems. Windows instructions might differ.

## Step 1: Clone & Build

The repo uses git submodules to bundle our forks of [go-ethereum](https://github.com/quilt/go-ethereum) and [solidity](https://github.com/quilt/solidity) with some additional resources to help with quickly spinning up a local AA testnet.

### Clone Recursively

To clone this repo and both submodules in one step, do:

```shell
git clone -b mvp-tutorials --recurse-submodules https://github.com/quilt/account-abstraction-playground.git
```

All further commands will be relative to this `account-abstraction-playground` base directory.
   
### Build Go-Ethereum

For building go-ethereum, you need the most recent version of Go. See [here](https://golang.org/doc/install) for Go install instructions.
On macOS, you also need the Xcode Command Line Tools, which you can install via `xcode-select --install`.

To compile `geth`, do:

```shell
cd go-ethereum
make geth
```

You should now have a `geth` executable at `build/bin/geth`.

### Build Solidity

See the [solidity documentation](https://solidity.readthedocs.io/en/v0.6.10/installing-solidity.html#building-from-source) for building prerequisites.

To compile `solc`, do:

```shell
cd solidity
mkdir build
cd build
cmake .. && make solc
```

You should now have a `solc` executable at `solc/solc`.

If you are running into a `Could NOT find Boost` issue on macOS, try `brew install boost-python`.

## Step 2: Create a Local Test Chain

The next step is to set up a local geth test chain. If you are already familiar with setting up geth testnets, you can skip this section and do the setup on your own.
Otherwise you can follow this simple 3-step process to set up a local Proof-of-Authority (PoA) testnet:

### Create a Signer Account

To create an account that will serve as the signer (PoA equivalent of a miner) for the testnet, do:

```shell
go-ethereum/build/bin/geth account new --datadir data
```

This should output the public address of the newly created account.
We will refer to this address as `<SIGNER>`.

### Create a Genesis File

Next you need to create a genesis file at `data/genesis.json` for the new test chain.
You can use the existing `data/genesis_template.json`, replacing the two occurrences of `<SIGNER>` with the address of your signer, in both cases without the leading `0x`.

### Initialize & Start the Chain

For the last step of the test chain setup, do (once again replacing `<SIGNER>`):

```shell
go-ethereum/build/bin/geth init --datadir data data/genesis.json
go-ethereum/build/bin/geth --unlock 0x<SIGNER> --datadir data --mine --http --http.api personal,eth --allow-insecure-unlock --networkid 12345 --nodiscover
```

After entering the signer account password, you should now see the local geth testnet running and producing new blocks every 3 seconds.


## Step 3: Deploy & Use Your First Account Abstraction Contract

This repo currently contains two example AA contracts.
The first one, `Whiteboard`, is a simple hello world AA contract that lets you write to and read from a virtual whiteboard.
The second one, `Wallet`, is a more interesting smart contract wallet example that uses `ecrecover` to only accept transactions signed by its owner.

For interacting with the AA test chain we are using `nodejs` with `web3.js` version `1.2.9`.

### [`Whiteboard`](contracts/Whiteboard.sol)

When you first look at the contract code, you can see a few small differences to normal solidity code:

- `pragma experimental AccountAbstraction;` tells the compiler to enable the experimental AA support.
- `account contract Whiteboard {...}` signals that `Whiteboard` is an AA contract.
  The compiler therefore includes the AA bytecode prefix at the beginning of the contract bytecode.
- `assembly { paygas(gasPrice) }` uses inline assembly and a new `paygas(...)` Yul function to call the new AA `PAYGAS` opcode with the provided gas price.
  `PAYGAS` is required in any AA contract execution (even for read-only access) and signals that the contract has decided to pay for the transaction.
  The provided gas price is used to deduct `gas price * gas limit` as total transaction cost from the contract balance.
  As with normal transactions, any unused gas is then refunded at the end of the transaction.


The `Whiteboard` contract itself has two variables:

- `uint256 nonce` is the contract's internal replay protection mechanism and mirrors the protocol-enshrined nonce functionality.
  While it is still an open question whether AA would use the protocol-enshrined nonce, for our MVP we have decided against it.
  Thus, all AA transactions have a protocol-level nonce of `0` and it is up to the contract to provide a replay protection mechanism.
- `string message` is the "whiteboard content". It can be changed by the contract via the `setMessage(...)` function.

Note that our MVP implementation does not currently support public variables, as the solidity-defined getter functions do not call `PAYGAS` and are thus not AA compliant.
Instead, the contract provides `getNonce()` and `getMessage()` as getters for `nonce` and `message` respectively.

To "write" a new message to the whiteboard, the contract provides `function setMessage(uint256 txNonce, uint256 gasPrice, string calldata newMessage, bool failAfterPaygas)`.
This function takes four parameters:

- `txNonce` is the nonce of the transaction. If it is not equal to the current value of `nonce`, execution aborts without ever reaching `PAYGAS`.
  In that case the transaction would not only fail, but would be considered invalid and could not even be included in a block.
  If instead the nonce is valid, the contract then increments its internal nonce by one, making this transaction un-replayable in the future.
- `gasPrice` is the gas price the contract is supposed to pay for the transaction.
  While under AA the contract could decide this value on its own, it here lets the caller set it.
- `newMessage` is the new message string that replaces the old `message`.
- `failAfterPaygas` is an extra parameter for AA experimentation.
  If set to `true`, the contract will throw.
  As `PAYGAS` has already been called at that point, the contract has already committed to paying for the transaction.
  Thus, the result is a valid, but failed transaction. If the transaction is included in a block, the contract balance will be reduced by the total transaction fee and `nonce` will be incremented by one.
  In contrast, any state changes after `PAYGAS`, in this case the message update, are reverted, resulting in an unchanged `message`.

### [`Wallet`](contracts/Wallet.sol)