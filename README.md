# DeFi Stablecoin Protocol

### Overview
The protocol consists of an ERC20 stablecoin and is governed by its engine smart contract. The stablecoin is algorithmic and exogenous. The engine allows protocol participants to mint stablecoins by depositing collateral tokens and redeem collateral tokens by burning stablecoins. It also incorporates a health factor to assess and monitor the health of user positions, ensuring they stay overcollateralized. There is a liquidation mechanism that allows anyone to liquidate undercollateralized positions to restore protocol solvency in return for some bonus rewards. Since the stablecoin price is intended to be pegged to $1, the USD prices of collateral tokens are fetched using Chainlink price feeds. The entire project is built using Foundry and the test suite consists of unit and fuzz tests along with handler based invariant tests.

### Getting started
- Ensure you have Foundry and Git installed
```bash
# should return output like `git version 2.43.0`
git --version

# should return output like `forge 0.2.0 (bcacf39 2024-10-13T00:22:05.416295704Z)`
forge --version
```
- Clone the repo
```bash
git clone https://github.com/dt6120/defi-stablecoin-protocol.git
```
- Deploy stablecoin and engine smart contracts using script
```bash
forge script script/DeployDSC.s.sol
```
- Run tests
```bash
# unit and fuzz tests
forge test --mt test_

# invariant tests
forge test --mt invariant_

# all tests
forge test
```
- Check test suite coverage
```bash
forge coverage
```

### Known issues
- Protocol assumes collateral tokens have 18 decimals, other decimal value can break protocol.
- Liquidation breaks when user position is <110% collateralized.
- Stale price data halts the protocol functionality.
- Current overcollateralization ratio and liquidation bonus percentage do not mathematically incentivize others to perform liquidation.
