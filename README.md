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
git clone --recurse-submodules git@github.com:quilt/account-abstraction-playground.git
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
We will refer to this address (without `0x`) as `<SIGNER>`.

### Create a Genesis File

Next you need to create a genesis file at `data/genesis.json` for the new test chain.
You can use the existing `data/genesis_template.json`, replacing the two occurrences of `<SIGNER>` with the address of your signer.

### Initialize & Start the Chain

For the last step of the test chain setup, do (once again replacing `<SIGNER>`):

```shell
go-ethereum/build/bin/geth init --datadir data data/genesis.json
go-ethereum/build/bin/geth --unlock 0x<SIGNER> --datadir data --mine --http --http.api personal,eth --allow-insecure-unlock --networkid 12345 --nodiscover
```

After entering the signer account password, you should now see the local geth testnet running and producing new blocks every 3 seconds.


## Step 3: Deploy & Use Your First Account Abstraction Contract

This repo currently contains two example AA contracts.
Both have their own instructions for deployment and usage that you can find linked below:

- [`Whiteboard`](contracts/Whiteboard.sol) is a simple hello world AA contract that lets you write to and read from a virtual whiteboard.
- [`Wallet`](contracts/Wallet.sol) is a more interesting smart contract wallet example that uses `ecrecover` to only accept transactions signed by its owner.
