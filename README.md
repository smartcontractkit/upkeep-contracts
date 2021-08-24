# Upkeep Contracts

This repo contains keeper-compatible contracts that serve various use cases.

### Requirements
```
node 12+
python 3
solc 0.8.6 (for slither)
```

### Install Dependencies
```bash
yarn install
pip3 install -r requirements.txt
```

### Compile
```bash
yarn compile
```

### Run tests
```bash
yarn test
```

### Slither Static Analysis

Warning: the slither static analysis requires some massaging to get working.

```bash
slither .
```

### Flatten

```bash
# replace MyUpkeepContract
yarn --silent run hardhat flatten ./contracts/upkeeps/MyUpkeepContract.sol > MyUpkeepContract.flattened.sol
```
