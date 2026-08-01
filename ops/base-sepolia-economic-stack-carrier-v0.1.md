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

## Successful deployment run

```text
run: 30690661623
simulation: pass
nonceRecheckBeforeBroadcast: pass
broadcast: pass
foundryResult: ONCHAIN EXECUTION COMPLETE & SUCCESSFUL
operatorNonceBefore: 2
operatorNonceAfterExpected: 10
```

The immediate finalizer failed only because a public RPC node had not yet propagated bytecode for the final `TradeProofSeasonAllocation` address. A second deployment is forbidden.

## Deployed address set from successful script output

```text
communityTreasury: 0xBf485863EA313b75dC6cf389A9A86Bd98a0dF910
ecosystemTreasury: 0x3Ca8dd7dF625d51aF1Da77716269D788DD869089
adoptionTreasury: 0x895C0C8749EF5DE94BA544cf28dDEd68fd6b3Aba
liquidityReserve: 0xC7F135d85aAe58bd409F7263FadbD041d6031B92
securityReserve: 0x594ce0619d5bAcA2F66992c89610cb57A704d0AB
contribution: 0xcb33eA69dDa48f2A345Fc1F2A3B85f329a5eb1E0
genesis: 0x2a00707664d738d41EDc4e453F173D38f6D83ECb
seasonAllocation: 0x0bFd6CEab5dB51d7B53789484ECD147B10D7fC65
token: 0xd0a60427482C2cBE1C6566772DC5838AA06DED80
teamVesting: 0x65Ab9CE997975f18b6a06957D75AA5a00b3dc467
```

## Read-only evidence recovery

```text
recoveryControlMain: 439a90515aa80f163de99505f2f7ebede35992fc
recoveryTrigger: 2026-08-01-v1
privateKeyAvailableToJob: false
signingAvailable: false
broadcastAvailable: false
expectedOperatorNonce: 10
expectedDeploymentTransactions: 8
```

The recovery job only reads Base Sepolia RPC and Blockscout data. It reconstructs nonces `2..9`, verifies all receipts and contract addresses, waits for bytecode propagation, checks the fixed supply and exact allocations, and preserves a machine-readable manifest.

Required inactive state remains:

```text
Season 0 proposal: none
Community committed: zero
Claim active: false
Public sale: false
Liquidity pool: none
Mainnet authorization: false
```

After successful evidence preservation:

1. create a separate canonical manifest PR;
2. close this carrier without merging;
3. keep every claim, sale, liquidity and mainnet action disabled.
