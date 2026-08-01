# ChainTrace Contracts

**Minimal smart contracts for the Trade Proof and ChainTrace proof layer.**

This repository is the canonical Solidity source of truth for Trade Proof contracts.

## Canonical v0.1 contracts

### TradeProofRegistry.sol

`TradeProofRegistry` anchors canonical digests of:

- Trade Proof Passports;
- Trade Proof Responses.

It records issuer, block time, artifact kind, Response subject, schema/profile hashes, supersession links, and revocation state. It does not store source documents or commercial plaintext.

The digest profile is documented in:

```text
docs/trade-proof-registry-v0.1.md
```

### TradeProofContribution.sol

`TradeProofContribution` records non-transferable contribution receipts and seasonal Proof Points derived from current Registry anchors and governed public-goods review.

Implemented automatic contribution classes:

```text
unique Passport                          +5 issuer
independent external Response            +10 Passport issuer / +20 responder
third distinct responder role            +30 Passport issuer
viral reuse within 30 days               +50 inviter / +25 new creator
repeat use across two lineages           +20 participant
```

Implemented reviewed public-goods classes:

```text
accepted standard change                    500–3,000
production connector or Agent integration 1,500–10,000
security finding or fix                     500–15,000
verified repeat adoption case             1,000–10,000
documentation, translation, or education    100–2,000
```

Economic controls:

```text
season length                              90 days
receipt review delay                       30 days
appeal window                              14 days
viral reuse window                         30 days
minimum eligibility                        25 points
automatic wallet/day cap                  200 points
automatic wallet-pair/season cap          300 points
```

Receipts and Proof Points are not ERC-20 or ERC-721 assets and have no transfer function. The contract does not mint, distribute, sell, price, or move TPROOF.

The bounded implementation contract is documented in:

```text
docs/trade-proof-contribution-v0.1.md
```

The canonical economic constitution remains in:

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

The machine-readable Registry deployment record is:

```text
deployments/base-sepolia.json
```

`TradeProofContribution` is not yet deployed. A future testnet deployment requires this implementation PR, test and security gates, exact-source evidence, and a separate deployment review.

## Contract architecture

```text
Trade Proof Passport / Response JSON
        ↓ canonicalization profile
Keccak-256 artifact digest
        ↓
TradeProofRegistry
        ↓ current onchain artifact facts
TradeProofContribution
        ↓ delayed non-transferable receipts
Seasonal verified Proof Points
        ↓ future and not implemented here
TPROOF allocation / Token contracts
```

Evidence documents remain off-chain. Evidence-level SHA-256 hashes inside a Passport are distinct from the canonical Passport or Response digest anchored by `TradeProofRegistry`.

Token holdings, staking, receipts, or Proof Points cannot make a Passport, Response, evidence record, or real-world assertion valid.

## Legacy proof primitives

The following contracts are retained as early ChainTrace proof primitives:

```text
contracts/ProofRegistry.sol
contracts/BatchRegistry.sol
contracts/EventRegistry.sol
```

They are not canonical Trade Proof Passport or contribution contracts and should not be extended into competing Passport, lifecycle, receipt, or points systems.

## Current scope

Implemented:

- Passport and Response digest anchoring;
- same-issuer version supersession;
- Response subject continuity;
- issuer-controlled revocation;
- current/history queries;
- bounded contribution receipts and Proof Points;
- independent-response, role, viral-reuse, and repeat-use rules;
- reviewed public-goods submissions;
- review delay, exclusion, appeal, revocation, caps, and season closure;
- Foundry tests;
- canonical Registry Base Sepolia deployment;
- Foundry and DLSK CI gates.

Not implemented:

- `TradeProofToken.sol`;
- Token issuance, claims, distribution, sale, or liquidity;
- square-root seasonal Token allocation execution;
- production multisig, timelock, identity, or organizational-authority verification;
- payment, settlement, lending, disbursement, custody, or asset tokenization;
- Contribution contract testnet deployment;
- Registry explorer source verification;
- formal external smart-contract audit.

## Local development

Install Foundry and run:

```bash
forge fmt --check
forge build --sizes
forge test -vvv
```

## Security gate

Pull requests run:

```text
forge fmt --check
forge build --sizes
forge test -vvv
DLSK scan with fail-on-high
```

DLSK is a pre-audit readiness gate, not a formal security audit.

## Design principles

```text
Proof, not exposure.
Hashes, not sensitive files.
Portable objects, not platform lock-in.
Evidence integrity, not automatic truth.
Contribution before liquidity.
Community incentives, not control of evidence validity.
```

## License

MIT.

## Disclaimer

These contracts are experimental and unaudited. They do not constitute a financial product, investment contract, token sale, lending system, payment system, legal attestation, or promise of future returns.
