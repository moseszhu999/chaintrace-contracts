# TPROOF Fixed-Supply Genesis v0.1

## Status

Bounded implementation for code review and testnet preparation. No Token contract in this document is deployed, claimable, offered for sale, or admitted to trading.

The canonical economic source remains:

```text
moseszhu999/trade-proof-passport
standard/tproof-token-economics-v0.1.md
tokenomics/tproof-tokenomics-v0.1.json
```

## Contracts

### TradeProofToken

A minimal ERC-20 with:

```text
name: TradeProof Token
symbol: TPROOF
decimals: 18
maximum and genesis supply: 1,000,000,000 TPROOF
post-genesis mint path: none
owner/admin role: none
transfer tax: none
forced-transfer function: none
upgrade function: none
```

All supply is created once in the constructor and allocated to six distinct nonzero recipients.

### TradeProofTeamVesting

An immutable escrow for the 15% team allocation:

```text
allocation: 150,000,000 TPROOF
cliff: 365 days
linear duration: 1,460 days
beneficiary: immutable
start timestamp: immutable and cannot be backdated
administrator: none
```

At the 12-month cliff, 25% is vested. The balance then continues linearly until the end of the 48-month schedule. Anyone may trigger release, but tokens can only reach the immutable beneficiary.

### TradeProofGenesis

An atomic deployment factory that:

1. validates six distinct economic beneficiaries;
2. deploys the fixed-supply Token;
3. temporarily receives the team allocation;
4. deploys the immutable team vesting escrow;
5. transfers the full 150,000,000 TPROOF team allocation into the escrow;
6. asserts the one-billion supply, zero factory balance, and exact escrow balance.

The factory has no post-deployment control functions.

## Exact genesis allocation

```text
Community contributions              450,000,000  45%
Ecosystem and developer fund         200,000,000  20%
Core team vesting                    150,000,000  15%
Real adoption incentives             100,000,000  10%
Liquidity bootstrapping reserve       50,000,000   5%
Security and standards reserve        50,000,000   5%
                                    -----------
                                  1,000,000,000 100%
```

The liquidity allocation is only a reserved Token bucket. This implementation does not create a pool, market, price, sale, claim, or trading venue.

## Separation from evidence and contribution accounting

```text
TradeProofRegistry
  determines onchain digest chronology and current state

TradeProofContribution
  records non-transferable receipts and seasonal Proof Points

TradeProofToken
  transfers future community-economic units
```

Token ownership, allowance, transfer, vesting, or treasury allocation cannot:

- validate a Passport or Response;
- change Registry history;
- create contribution points;
- approve a reviewed contribution;
- prove identity or organizational authority;
- create ownership of goods, invoices, receivables, payments, or other real-world assets.

## Deliberately not implemented

- public claim contract;
- seasonal square-root allocation contract;
- Genesis Proof eligibility root;
- liquidity pool or market action;
- sale, presale, auction, or pricing;
- staking yield;
- revenue share or dividend;
- governance execution;
- treasury multisig or timelock;
- production deployment scripts;
- proxy or upgrade mechanism.

Those remain separate launch-gated slices. A testnet Token deployment does not authorize a public offer, liquidity action, or mainnet launch.

## Security posture

This implementation is intended to pass:

```text
forge fmt --check
forge build --sizes
forge test -vvv
DLSK 0 HIGH / 0 CRITICAL
```

These checks are not an independent external audit or legal review.
