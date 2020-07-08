# Account Abstraction Playground

The goal of this playground repo is to get you to create your first real-world account abstraction (AA) contract in 3 simple steps.
Account abstraction is the proposed idea of letting contracts validate and pay for their own transactions, without the involvement of EOAs (i.e. private key accounts).


This repo is part of the Quilt team's R&D effort on the feasibility of bringing AA to eth1.
At the core of this effort is our fork of go-ethereum that implements a basic version of AA as [outlined by Vitalik](https://ethereum-magicians.org/t/implementing-account-abstraction-as-part-of-eth1-x/4020) earlier this year.
We are currently in the process of collecting metrics and will be writing a comprehensive overview of our work so far and our future goals once that is done.
In the meantime, this repo aims to enable anyone interested to already explore our current AA MVP implementation.
It tracks the latest stable version of our go-ethereum fork and as such is subject to change as we continue development.
Note that at the current time we do not yet have a position on bringing AA to mainnet, but will communicate our assessment of AA feasibility as part of our upcoming writeup.

The following instructions are written for macOS, but should be similar for most Linux systems. Windows instructions might differ.

## Step 1: Clone & Build

The repo uses git submodules to bundle our forks of [go-ethereum](https://github.com/quilt/go-ethereum) and [solidity](https://github.com/quilt/solidity) with some additional resources to help with quickly spinning up a local AA testnet.

#### Clone Recursively

To clone this repo and both submodules in one step, do:

```shell
git clone -b mvp-tutorials --recurse-submodules https://github.com/quilt/account-abstraction-playground.git
```

All further commands will be relative to this `account-abstraction-playground` base directory.
   
#### Build Go-Ethereum

For building go-ethereum, you need the most recent version of Go. See [here](https://golang.org/doc/install) for Go install instructions.
On macOS, you also need the Xcode Command Line Tools, which you can install via `xcode-select --install`.

To compile `geth`, do:

```shell
cd go-ethereum
make geth
```

You should now have a `geth` executable at `build/bin/geth`.

#### Build Solidity

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

#### Create a Signer Account

To create an account that will serve as the signer (PoA equivalent of a miner) for the testnet, do:

```shell
go-ethereum/build/bin/geth account new --datadir data
```

This should output the public address of the newly created account.
We will refer to this address as `<SIGNER>`.

#### Create a Genesis File

Next you need to create a genesis file at `data/genesis.json` for the new test chain.
You can use the existing `data/genesis_template.json`, replacing the two occurrences of `<SIGNER>` with the address of your signer, in both cases without the leading `0x`.

#### Initialize & Start the Chain

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

### `Whiteboard`

The contract file for the `Whiteboard` contract can be found at [`contracts/Whiteboard.sol`](contracts/Whiteboard.sol).

#### Description

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
  While it is still an open question whether AA would use the protocol-enshrined nonce, the MVP does not do so.
  Thus, all AA transactions have a protocol-level nonce of `0` and it is up to the contract to provide a replay protection mechanism.
- `string message` is the "whiteboard content". It can be changed by the contract via the `setMessage(...)` function.

Note that the MVP implementation does not currently support public variables, as solidity-defined getter functions do not call `PAYGAS` and are thus not AA compliant.
Instead, the contract provides `getNonce()` and `getMessage()` as getters for `nonce` and `message` respectively.

To "write" a new message to the whiteboard, the contract provides `function setMessage(uint256 txNonce, uint256 gasPrice, string calldata newMessage, bool failAfterPaygas)`.
This function takes four parameters:

- `txNonce` is the nonce of the transaction. If it is not equal to the current value of `nonce`, execution aborts without ever reaching `PAYGAS`.
  In that case the transaction not only fails, but is considered invalid and cannot be included in a block.
  If instead the nonce is valid, the contract then increments its internal nonce by one, making this transaction un-replayable in the future.
- `gasPrice` is the gas price the contract is supposed to pay for the transaction.
  While under AA the contract could decide this value on its own, it here lets the caller set it.
- `newMessage` is the new message string that replaces the old `message`.
- `failAfterPaygas` is an extra parameter for AA experimentation.
  If set to `true`, the contract will throw.
  As `PAYGAS` has already been called at that point, the contract has already committed to paying for the transaction.
  Thus, the result is a valid, but failed transaction. If the transaction is included in a block, the contract balance will be reduced by the total transaction fee and `nonce` will be incremented by one.
  In contrast, any state changes after `PAYGAS`, in this case the message update, are reverted, resulting in an unchanged `message`.

Finally, the contract also contains an empty `constructor() public payable`, which allows ETH transfer to the contract as part of its deployment.
Given that AA contracts have to pay for their own transaction, transfering some ETH to it is required.
While the AA prefix of the MVP implementation also allows for incoming ETH transfers to a deployed AA contract, sending ETH as part of the initial deployment makes this extra step unnecessary.

#### Compile Contract

To compile the `Whiteboard` contract with the forked version of solidity, do:

```shell
solidity/build/solc/solc --bin --abi contracts/Whiteboard.sol
```

This should output both the contract bytecode, which we will reference as `<BYTECODE>`, as well as its ABI, which we will reference as `<ABI>`.

#### Deploy Contract to Local Chain

To deploy the compiled contract to the local AA test chain, you first have to ensure geth is still running.
If that is not the case, you can start geth back up via

```shell
go-ethereum/build/bin/geth --unlock 0x<SIGNER> --datadir data --mine --http --http.api personal,eth --allow-insecure-unlock --networkid 12345 --nodiscover
```

The interaction with the chain will now happen from inside `nodejs`, where we first import `web3.js` and connect it to geth:

```javascript
const Web3 = require('web3');
let web3 = new Web3('http://localhost:8545');
let signer = '0x<SIGNER>';
web3.eth.getBalance(signer).then(console.log);
```

If you replaced `<SIGNER>` with your signer address, you should now see the current balance of your signer account.

You can now deploy the `Whiteboard` contract:

```javascript
let bytecode = '0x<BYTECODE>';
let abi = <ABI>;  // note: no quotes!
let Contract = new web3.eth.Contract(abi);
let contract;
Contract.deploy({data: bytecode}).send({from: signer, value: 10000000}).then(function(contractInstance){contract = contractInstance; console.log(contractInstance);});
```

After a few seconds, the AA contract should now be deployed and referenced by the `contract` variable.
The deployment itself was a normal Ethereum transaction, paid for by the signer account.
As the signer is also the block producer and thus collects all transaction fees, the only balance change is the `10000000 wei` sent to the contract as part of its deployment.
To inspect the current balances, you can do:

```javascript
web3.eth.getBalance(contract._address).then(console.log);
web3.eth.getBalance(signer).then(console.log);
```

#### Send Your First AA Transaction

Before sending the first AA transaction, you can first use the static getter functions to read the current contract state:

```javascript
contract.options.from = '0xffffffffffffffffffffffffffffffffffffffff';
contract.methods.getNonce().call().then(console.log);
contract.methods.getMessage().call().then(console.log);
```

This should output a currently empty `message` and a `nonce` of `0`.
Note the first line, where the default address for contract interactions is set to the entry point address.
This is required already for static `ethcall` interactions in order to pass the AA bytecode prefix.

You can now send your first AA transaction:

```javascript
contract.methods.setMessage(0, 1, "hello world!", false).send({gasPrice: "0", gasLimit: 100000}).then(console.log);
```

After a few seconds, the transaction - your first ever AA transaction - should make its way into a block.
To analyze the effect of this transaction, we can again inspect the relevant parts of the chain state:

```javascript
contract.methods.getNonce().call().then(console.log);
contract.methods.getMessage().call().then(console.log);
web3.eth.getBalance(contract._address).then(console.log);
web3.eth.getBalance(signer).then(console.log);
```

As you should see, the transaction was successfully executed, incrementing the contract `nonce` by one and setting its `message`.
Furthermore, the contract balance is decreased, indicating that the contract did in fact pay for the transaction on its own.
The signer account had no part in this interaction directly (the caller address was the `0xffffffffffffffffffffffffffffffffffffffff` entry point address) and only collected the transaction fee in its role as block producer.

This concludes the demonstration of the `Whiteboard` contract.
Feel free to play around with the contract some more - this is the Account Abstraction Playground after all - e.g. by sending a transaction with `failAfterPaygas = true`.
For a somewhat more advanced use case, we will next look at the `Wallet` contract.

### `Wallet`

The contract file for the `Wallet` contract can be found at [`contracts/Wallet.sol`](contracts/Wallet.sol).

#### Description

The `Wallet` contract contains 2 variables:

- `uint256 nonce` is the contract's internal replay protection analogous to the one used in the `Whiteboard` example.
- `address owner` is the contract owner and gets set to the account that deploys the contract.
  The owner has to sign all outgoing transfers from the wallet.
  
The contract inherits ECDSA signature verification logic from [`contracts/ECDSA.sol`](contracts/ECDSA.sol), which is based on the [OpenZeppelin ECDSA library](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/cryptography/ECDSA.sol).
The only change from the OppenZeppelin original is the change from a library to a contract that the `Wallet` contract then inherits from.
As signature verification happens before `PAYGAS`, the AA opcode restrictions apply.
For the MVP, these include a ban of the `DELEGATECALL` used for library interactions.
As AA transaction verification must not rely on external state, there are concerns around library contracts changing their code via `SELFDESTRUCT`, thus potentially rendering previously valid AA transactions invalid.
Thus, for the MVP one has to directly inherit from the `ECDSA` contract such that all of its logic gets deployed together with the rest of the `Wallet` contract.
In contrast to library interactions, calling into precompiles via `STATICCALL` is allowed even before `PAYGAS`.
The `ECDSA` makes use of this by internally calling the `ecrecover` precompile for reconstruction of the signer address.
The relevant function provided by the contract is `recover(bytes32 hash, bytes memory signature)`, which takes a message hash and a 65-byte signature and returns the address of the account that signed the message.

To transfer ETH from the wallet to an external address, the contract provides `function transfer(uint256 txNonce, uint256 gasPrice, address payable to, uint256 amount, bytes calldata signature)`.
This function takes five parameters:

- `txNonce` is the nonce of the transaction as in `Whiteboard.setMessage(...)`.
- `gasPrice` is the gas price the contract is supposed to pay for the transaction as in `Whiteboard.setMessage(...)`.
- `to` is the recipient address.
- `amount` is the amount in wei to be transferred to the address.
- `signature` is the 65-byte signature of the transaction.
  It consists of the 32-byte `r`, 32-byte `s`, and 3-byte `v` values of the ECDSA signature over the hash of `contract._address, txNonce, gasPrice, to, amount`.

#### Compile & Deploy Contract

To compile the `Wallet` contract, do:

```shell
solidity/build/solc/solc --bin --abi contracts/Wallet.sol
```

This should output both the contract bytecode, which we will reference as `<BYTECODE>`, as well as its ABI, which we will reference as `<ABI>`.

To deploy the contract in `nodejs`, do:

```javascript
const Web3 = require('web3');
let web3 = new Web3('http://localhost:8545');
let signer = '0x<SIGNER>';
let bytecode = '0x<BYTECODE>';
let abi = <ABI>;  // note: no quotes!
let Contract = new web3.eth.Contract(abi);
let contract;
Contract.deploy({data: bytecode}).send({from: signer, value: 10000000}).then(function(contractInstance){contract = contractInstance; console.log(contractInstance);});
```

#### Send Transaction

As an example transaction, you are going to send `42 wei` to the `0x0000000000000000000000000000000000000000` address.
Before doing so, you can inspect the current chain state via:

```javascript
let zeroAddress = '0x0000000000000000000000000000000000000000';
contract.options.from = '0xffffffffffffffffffffffffffffffffffffffff';
contract.methods.getNonce().call().then(console.log);
contract.methods.getOwner().call().then(console.log);
web3.eth.getBalance(contract._address).then(console.log);
web3.eth.getBalance(zeroAddress).then(console.log);
web3.eth.getBalance(signer).then(console.log);
```

As you can see, the signer account that deployed the AA contract is registered as its owner.
To send a transfer, you thus first have to create and sign the transaction hash from the signer account:

```javascript
let hash = web3.utils.soliditySha3(contract._address, 0, 1, zeroAddress, 42);
let txSignature;
web3.eth.personal.sign(hash, signer).then(function(signature){txSignature = signature;});
```

You can then send the transfer as an AA transaction:

```javascript
contract.methods.transfer(0, 1, zeroAddress, 42, txSignature).send({gasPrice: "0", gasLimit: 100000}).then(console.log);
```

After a few seconds, the transaction should be included in a block.
The contract balance should be reduced by the sum of the transaction fee and the `42 wei` sent out.
The balance of the zero address should now be `42 wei`.
