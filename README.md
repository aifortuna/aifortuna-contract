## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

### 将 json 转化成 abi 文件,out/Fortuna.sol 路径下执行

```shell
jq '.abi' ./out/Fortuna.sol/Fortuna.json > ./Fortuna.abi
```

### 将 json 转化成 abi 文件,out/Runesoul.sol 路径下执行

```shell
jq '.abi' ./out/Runesoul.sol/Runesoul.json > ./Runesoul.abi

jq '.abi' ./out/AGT.sol/AGT.json > ./AGT.abi

jq '.abi' ./out/FUSD.sol/FUSD.json > ./FUSD.abi

jq '.abi' ./out/NodeCard.sol/NodeCard.json > ./NodeCard.abi

jq '.abi' ./out/Fortuna.sol/Fortuna.json > ./Fortuna.abi

jq '.abi' ./out/Treasury.sol/Treasury.json > ./Treasury.abi
```

## forge build 提示错误信息

Error: script failed: revert: Failed to run upgrade safety validation: /Users/j/.npm/\_npx/e9c2fe9985ed1095/node_modules/@openzeppelin/upgrades-core/dist/cli/validate/build-info-file.js:127
throw new error_1.ValidateCommandError(`Build info file ${buildInfoFilePath} is not from a full compilation.`, () => PARTIAL_COMPILE_HELP);

```
forge clean
forge build --build-info
```

## 生产部署-> 部署者和 admin 要区分开,如果是 token,则不需要.

- fortuna,nodecard,treasury 单个合约,proxyAdmin,不可以和 owner 一致.
