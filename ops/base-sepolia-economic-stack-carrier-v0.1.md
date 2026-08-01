# Base Sepolia Economic Stack Deployment Carrier v0.1

This pull request is an operational carrier and must not be merged.

## Exact source

```text
d89dd24eba52aa49ffed00ca8c6e450444214c2b
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

## Exact command

Only the repository owner may trigger the one-time workflow with this exact PR comment:

```text
/deploy-tradeproof-economic-stack-base-sepolia-v0.1
```

The workflow must use the existing `DEPLOYER_PRIVATE_KEY` repository secret without printing it, derive the public operator address, verify Base Sepolia and the canonical Registry, simulate before broadcast, broadcast once, verify every deployed contract and allocation, and preserve a machine-readable evidence artifact.

## Read-only preflight synchronization

```text
integratedProbeMain: 0b6e1c0ba7143d02cc47ab8c7daf6561ff4b2a53
probeTrigger: 2026-08-01-v1
probeRun: 30688305004
operatorNonce: 2
nonceStatus: baseline-clear
transactionAuthorized: false
```

## Guarded deployment synchronization

```text
deploymentWorkflowMain: addcbf15325b5053a874d08be12814d1d8ae7c42
exactFormatFixMain: e5b534b1a43297eeef67712de4c136171af7afc4
previousRun: 30688700840
previousRunStoppedBeforePreflight: true
previousRunSimulationEntered: false
previousRunBroadcastEntered: false
deploymentTrigger: 2026-08-01-v2
expectedStartingNonce: 2
expectedEndingNonce: 10
testnetOnly: true
claimAuthorized: false
saleAuthorized: false
liquidityAuthorized: false
mainnetAuthorized: false
```

This commit triggers the exact carrier-branch job in the existing Contract validation workflow. Foundry, DLSK and the nonce probe must pass before simulation and the single broadcast.

After successful evidence preservation:

1. create a separate canonical manifest PR;
2. remove the one-time workflow from `main`;
3. close this carrier without merging;
4. keep every claim, sale, liquidity and mainnet action disabled.
