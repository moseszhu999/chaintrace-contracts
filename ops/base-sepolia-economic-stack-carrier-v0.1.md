# Base Sepolia Economic Stack Deployment Carrier v0.1

This pull request is an operational carrier and must not be merged.

## Exact source

```text
005839c62c1a67392b2f5cced25374f5b48fecc1
```

## Canonical Registry

```text
Network: Base Sepolia
Chain ID: 84532
Registry: 0xad1c714140ceb8ed7c5234d939a06926f5edaba2
```

## Authorized operation

Deploy the source-reviewed testnet-only economic stack:

- five explicit testnet treasury vaults;
- TradeProofContribution;
- TradeProofGenesis;
- TradeProofToken;
- TradeProofTeamVesting;
- TradeProofSeasonAllocation.

## Required initial state

```text
Token supply: 1,000,000,000 TPROOF
Season proposal: none
Season funding: zero
Claim active: false
Public sale: false
Liquidity pool: none
Market: none
Mainnet authorization: false
```

## Read-only preflight synchronization

```text
probeRun: 30688305004
operatorNonce: 2
nonceStatus: baseline-clear
transactionAuthorized: false
```

## Prior guarded runs

```text
run30688700840:
  stoppedAt: exact-source formatting
  simulationEntered: false
  broadcastEntered: false
run30688996234:
  stoppedAt: simulation timestamp drift
  simulationEntered: true
  broadcastEntered: false
```

## Current guarded deployment synchronization

```text
deploymentControlMain: 33a6cbc01bbfe1d0098a6e09721db3c8d46fefe4
reviewedSource: 005839c62c1a67392b2f5cced25374f5b48fecc1
vestingStartDelay: 1 hour
deploymentTrigger: 2026-08-01-v3
expectedStartingNonce: 2
expectedEndingNonce: 10
nonceRecheckImmediatelyBeforeBroadcast: true
testnetOnly: true
claimAuthorized: false
saleAuthorized: false
liquidityAuthorized: false
mainnetAuthorized: false
```

This commit triggers the exact carrier-branch job in the existing Contract validation workflow. Foundry, DLSK and the nonce probe must pass before simulation. Simulation must pass and nonce must still equal `2` immediately before the single broadcast.

After successful evidence preservation:

1. create a separate canonical manifest PR;
2. remove the one-time deployment job from `main`;
3. close this carrier without merging;
4. keep every claim, sale, liquidity and mainnet action disabled.
