# ChainTrace Contracts

**Canonical Solidity contracts for the TradeProof proof and contributor economy.**

## Canonical contract stack

```text
TradeProofRegistry
  Passport / Response digest chronology and current state
        ↓
TradeProofContribution
  non-transferable contribution receipts and seasonal Proof Points
        ↓
TradeProofGenesis
  atomic fixed-supply Token and team-vesting deployment
        ├─ TradeProofToken
        └─ TradeProofTeamVesting
```

Token holdings, transfers, allowances, vesting, receipts, or Proof Points can never make a Passport, Response, evidence record, or real-world assertion valid.

## TradeProofRegistry

`TradeProofRegistry` anchors canonical Passport and Response digests with issuer, timestamp, schema/profile hashes, supersession links, revocation state, and Response subject continuity.

It does not store source documents or commercial plaintext.

```text
docs/trade-proof-registry-v0.1.md
```

## TradeProofContribution

`TradeProofContribution` records non-transferable receipts and seasonal Proof Points derived from current Registry anchors and governed public-goods review.

Automatic contribution classes:

```text
unique Passport                          +5 issuer
independent external Response            +10 Passport issuer / +20 responder
third distinct responder role            +30 Passport issuer
viral reuse within 30 days               +50 inviter / +25 creator
repeat use across two lineages           +20 participant
```

Reviewed public-goods ranges:

```text
accepted standard change                    500–3,000
production connector or Agent integration 1,500–10,000
security finding or fix                     500–15,000
verified repeat adoption case             1,000–10,000
documentation, translation, or education    100–2,000
```

Controls:

```text
season length                              90 days
receipt review delay                       30 days
appeal window                              14 days
viral reuse window                         30 days
minimum eligibility                        25 points
automatic wallet/day cap                  200 points
automatic wallet-pair/season cap          300 points
```

```text
docs/trade-proof-contribution-v0.1.md
```

## Fixed-supply TPROOF genesis

### TradeProofToken

Minimal ERC-20 properties:

```text
Name: TradeProof Token
Symbol: TPROOF
Decimals: 18
Maximum supply: 1,000,000,000
Genesis supply: 1,000,000,000
Post-genesis minting: none
Owner/admin role: none
Transfer tax: none
Forced transfer: none
Proxy/upgrade path: none
```

Exact constructor allocation:

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

The liquidity reserve is only an allocation bucket. No pool, sale, price, market, claim, or trading venue is implemented.

### TradeProofTeamVesting

The full team allocation is held by an immutable escrow:

```text
allocation: 150,000,000 TPROOF
cliff: 365 days
linear vesting duration: 1,460 days
beneficiary: immutable
start timestamp: immutable and cannot be backdated
administrator: none
```

At the 12-month cliff, 25% is vested. Anyone may trigger a release, but vested tokens only reach the immutable beneficiary.

### TradeProofGenesis

The atomic genesis factory:

1. validates six distinct nonzero economic beneficiaries;
2. deploys the fixed-supply Token;
3. deploys team vesting;
4. transfers all 150,000,000 team tokens into vesting;
5. verifies one-billion total supply, exact escrow balance, and zero factory balance;
6. exposes no post-deployment control function.

```text
docs/trade-proof-token-genesis-v0.1.md
```

The economic constitution remains canonical in:

```text
https://github.com/moseszhu999/trade-proof-passport/blob/main/standard/tproof-token-economics-v0.1.md
https://github.com/moseszhu999/trade-proof-passport/blob/main/tokenomics/tproof-tokenomics-v0.1.json
```

## Canonical Base Sepolia Registry deployment

```text
Network: Base Sepolia
Chain ID: 84532
Contract: TradeProofRegistry
Address: 0xad1c714140ceb8ed7c5234d939a06926f5edaba2
Transaction: 0x6ffcae50367e9087c736ff5c7edd7d30483aedb0e8082488a0d8a8784cbdd31c
Block: 44891502
Deployer: 0x072A01FE3DdbF351DAaf6Da70CE5E67f5101fEC9
Reviewed source: 27248faeed7f3eb88428fa8ce7979223e088429f
Deployed bytecode: 2433 bytes
Bytecode check: PASS
Explorer source verification: pending
```

```text
deployments/base-sepolia.json
```

`TradeProofContribution`, `TradeProofToken`, `TradeProofTeamVesting`, and `TradeProofGenesis` are not deployed by this implementation branch.

## Legacy proof primitives

```text
contracts/ProofRegistry.sol
contracts/BatchRegistry.sol
contracts/EventRegistry.sol
```

These are retained historical primitives, not competing Passport, contribution, or Token owners.

## Current implementation scope

Implemented in source:

- Passport and Response digest anchoring;
- supersession and revocation history;
- contribution receipts and seasonal Proof Points;
- automatic and reviewed contribution classes;
- anti-wash caps, review delay, appeals, revocation, and season closure;
- fixed one-billion TPROOF supply;
- exact six-bucket genesis allocation;
- immutable team cliff and linear vesting;
- atomic genesis invariant checks;
- Foundry and DLSK CI gates.

Not implemented or authorized:

- Token deployment;
- public claim or Genesis Proof distribution;
- square-root seasonal allocation execution;
- sale, presale, auction, pricing, or liquidity action;
- staking yield, revenue share, dividend, or redemption;
- governance execution;
- production multisig or timelock;
- payment, settlement, lending, custody, or asset tokenization;
- identity or organizational-authority verification;
- formal external smart-contract audit;
- legal launch clearance.

## Local validation

```bash
forge fmt --check
forge build --sizes
forge test -vvv
```

Pull requests also run DLSK and block any HIGH or CRITICAL finding. DLSK and Foundry are pre-audit gates, not a formal external audit.

## Design principles

```text
Proof, not exposure.
Contribution before liquidity.
Fixed supply, no hidden mint.
Long vesting, no instant team unlock.
Community economics, not control of evidence validity.
No public launch before technical, security, governance, and legal gates.
```

## License

MIT.

## Disclaimer

These contracts are experimental and unaudited. They do not constitute a financial product, investment contract, token sale, lending system, payment system, legal attestation, or promise of price, liquidity, yield, revenue share, redemption, or future returns.
