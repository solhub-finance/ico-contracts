# ico-contracts

# Pre-requisites

1. Create .secrets.json in the root of the project
2. Create an account on Infura grab the PROJECT ID
3. Create an account using Metamask
4. Copy the account Private Key and Infura PROJECT ID to .secrets.json file

```
{
    "TESTNET_PRIVATE_KEY": "Your account private key",
    "MAINNET_PRIVATE_KEY": "Your account private key",
    "INFURA_PROJECT_ID": "Infura Project Id"
}
```

**ABOVE STEPS SEEMS TOO MUCH, COMMENT OUT THE CONTENTS OF networks field FROM hardhat.config.js**