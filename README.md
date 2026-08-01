# ChainTrace Contracts

**Minimal smart contracts for the Trade Proof and ChainTrace proof layer.**

This repository is the canonical Solidity source of truth for Trade Proof contracts.

## Canonical v0.1 contract

### TradeProofRegistry.sol

`TradeProofRegistry` anchors canonical digests of:

- Trade Proof Passports;
- Trade Proof Responses.

It records:

- issuer wallet;
- block timestamp;
- artifact kind;
- Passport subject for a Response;
- schema hash;
- digest profile hash;
- supersession links;
- revocation state and reason hash.

It does not store source documents or commercial plaintext.

The initial digest profile is documented in:

```text
docs/trade-proof-registry-v0.1.md
```

## Canonical Base Sepolia deployment

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

The machine-readable deployment record is:

```text
deployments/base-sepolia.json
```

This is a testnet deployment. It does not represent a production launch, mainnet deployment, formal audit, verified organizational identity, or proof that an off-chain trade fact is true.

## Legacy proof primitives

The following contracts are retained as early ChainTrace proof primitives:

```text
contracts/ProofRegistry.sol
contracts/BatchRegistry.sol
contracts/EventRegistry.sol
```

They are not the canonical Trade Proof Passport registry and should not be extended into a competing Passport/version/revocation system.

- `ProofRegistry` anchors individual evidence-file hashes and references.
- `BatchRegistry` creates simple batch/order/shipment keys.
- `EventRegistry` records simple supply-chain event references.

Future compatibility work may map these legacy objects into Trade Proof Passport evidence and fact profiles.

## Contract architecture

```text
Trade Proof Passport / Response JSON
        ↓ canonicalization profile
Keccak-256 artifact digest
        ↓
TradeProofRegistry
        ↓
issuer + timestamp + schema/profile + lifecycle links
```

Evidence documents remain off-chain. Evidence-level SHA-256 hashes inside a Passport are distinct from the canonical Passport or Response digest anchored by `TradeProofRegistry`.

## Current scope

Implemented:

- Passport digest anchoring;
- Response digest anchoring against a current Passport;
- same-issuer version supersession;
- Response subject continuity;
- issuer-controlled revocation;
- current/history queries;
- Foundry tests;
- canonical Base Sepolia deployment;
- machine-readable deployment manifest;
- Foundry and DLSK CI gates.

Not implemented yet:

- `TradeProofContribution.sol`;
- `TradeProofToken.sol`;
- token issuance or distribution;
- contribution rewards;
- payment or settlement;
- lending or disbursement;
- custody;
- asset tokenization;
- production identity or organizational-authority verification;
- explorer source verification;
- formal external smart-contract audit.

## Local development

Install Foundry and run:

```bash
forge fmt --check
forge build
forge test -vvv
```

## Reviewed deployment procedure

A deployment must use a dedicated testnet-only wallet, simulate or build/test before broadcast, verify the transaction receipt and deployed bytecode, and record the exact address, transaction, block, deployer, source commit, compiler version, and explorer-verification state.

The deployment manifest template remains available at:

```text
deployments/base-sepolia.example.json
```

Private keys must never be committed, printed, included in artifacts, or posted in issues, pull requests, chat, screenshots, or documentation.

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
Community incentives, not control of evidence validity.
```

## License

MIT.

## Disclaimer

These contracts are experimental and unaudited. They do not constitute a financial product, investment contract, token sale, lending system, payment system, legal attestation, or promise of future returns.
