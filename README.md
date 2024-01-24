## Installation

1. Install Foundry [instructions](https://github.com/gakonst/foundry/blob/master/README.md#installation)
1. Install the [foundry](https://github.com/gakonst/foundry) toolchain installer (`foundryup`), update `forge` binaries, and install submodules:
```shell
curl -L https://foundry.paradigm.xyz | bash
foundryup
git submodule update --init --recursive
```

## Development

Building and running unit tests is straightforward.
```
$ forge build
$ forge test
```

## Deployment

Set environment variables found below, as well as `ETHERSCAN_API_KEY`. This assumes best-practice of using a JSON keystore file, as plaintext private keys are insecure. Password challenge will be interactive. Note the deployment script will output the expected address for the contract based on the deployer EOA's nonce, before the contract was actually deployed.
```shell
	forge script script/deploy.s.sol \
		--rpc-url ${ETH_RPC_URL} --sender ${DEPLOY_ADDRESS} --keystore ${DEPLOY_KEY} --broadcast -vvv --verify
```

⚠ If you run out of funds deploying, or deployment fails for some other reason, add `--resume` before rerunning. Failure to do so will result in duplicate contract deployments and a drained wallet.

If deploying to an OP stack chain (Optimism, Base, etc.), recommend including `--legacy --slow` parameters. Each chain generally has their own blockchain explorer.  For chains other than mainnet and sepolia, create an accoount and API key for each explorer, and set `ETHERSCAN_API_KEY` as appropriate for each chain.  , set `--verifier-url` accordingly.  Here is a partial list:
| chain | explorer | --verifier-url |
| ----- | -------- | ------------- |
| Arbitrum One | https://arbiscan.io/ | `https://api.arbiscan.io/api`  |
| Base         | https://basescan.org/ | `https://api.basescan.org/api` |
| Optimism     | https://optimistic.etherscan.io/ | `https://api-optimistic.etherscan.io/api`|
| Polygon PoS  | https://polygonscan.com/ | `https://api.polygonscan.com/api` |

If contract verification fails on the first pass, add `--resume` and rerun. Tooling should not challenge you for private keystore password if contracts were fully deployed.