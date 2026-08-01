# TradeProofRegistry v0.1

Status: deployed on Base Sepolia; explorer source verification and formal audit remain pending.

## Canonical testnet deployment

```text
Network: Base Sepolia
Chain ID: 84532
Address: 0xad1c714140ceb8ed7c5234d939a06926f5edaba2
Transaction: 0x6ffcae50367e9087c736ff5c7edd7d30483aedb0e8082488a0d8a8784cbdd31c
Block: 44891502
Deployer: 0x072A01FE3DdbF351DAaf6Da70CE5E67f5101fEC9
Reviewed source commit: 27248faeed7f3eb88428fa8ce7979223e088429f
Solidity: 0.8.24
Deployed bytecode: 2433 bytes
Bytecode check: PASS
Explorer source verification: pending
```

The canonical machine-readable record is `deployments/base-sepolia.json`.

This deployment proves only that the reviewed bytecode was deployed at the recorded testnet address. It does not prove any off-chain fact, legal authority, organizational identity, production readiness, mainnet readiness, or financial claim.

## Purpose

`TradeProofRegistry` anchors deterministic digests of two portable objects:

- Trade Proof Passport
- Trade Proof Response

It records who anchored a digest, when it was anchored, which schema and digest profile were used, whether it was revoked, and whether it was superseded by a later version.

The registry is an integrity and chronology layer. It does not prove that a real-world trade fact is true, that the issuer was authorized by an organization, or that the object has legal, customs, insurance, financing, payment, settlement, ownership, or title effect.

## Canonical digest profile

The initial profile identifier is:

```text
trade-proof-passport-jcs-keccak256-v0.1
```

The profile hash passed to the contract is:

```text
keccak256(UTF8("trade-proof-passport-jcs-keccak256-v0.1"))
```

The artifact digest is produced as follows:

```text
Trade Proof Passport or Response JSON
→ remove no fields and add no presentation-only fields
→ canonicalize with JSON Canonicalization Scheme semantics
→ encode canonical JSON as UTF-8
→ keccak256(canonical UTF-8 bytes)
→ bytes32 artifact digest
```

Implementations must not hash ordinary pretty-printed JSON directly. Whitespace, object-member order, number serialization, and Unicode handling must follow the selected canonicalization profile.

## Evidence digest distinction

Evidence files inside a Passport may continue to use SHA-256 or another declared algorithm. That file digest is not the same object as the Passport artifact digest.

```text
Evidence digest
  identifies exact evidence bytes

Passport digest
  identifies the canonical complete Passport JSON object

Response digest
  identifies the canonical complete Response JSON object
```

The contract does not recompute off-chain digests. Clients and independent verifiers must reproduce the canonical digest and compare it with the on-chain bytes32 value.

## Anchor model

Each anchor records:

```text
issuer
anchoredAt
revokedAt
kind: Passport | Response
subjectDigest
schemaHash
digestProfileHash
supersedesDigest
successorDigest
revocationReasonHash
```

For a Passport, `subjectDigest` is zero.

For a Response, `subjectDigest` is the current Passport digest addressed by that response.

## Version rules

A new artifact may supersede an earlier artifact only when:

- the predecessor exists;
- the predecessor was anchored by the same issuer;
- the predecessor is still current;
- predecessor and successor have the same artifact kind;
- for Responses, both versions address the same Passport digest.

A superseded artifact remains queryable but is no longer current.

## Revocation rules

Only the original issuer may revoke a current artifact. Revocation records the block time and an optional hash of an off-chain reason.

The reason itself should remain off-chain unless it is intentionally public.

## Privacy boundary

The contract stores no:

- organization names;
- personal names;
- party IDs;
- goods descriptions;
- source documents;
- evidence URIs;
- commercial amounts;
- bank account data;
- wallet-to-legal-entity assertion;
- full revocation reason.

## Current non-goals

This contract does not perform:

- identity verification;
- organizational authority verification;
- legal signing;
- fact adjudication;
- token minting;
- contribution rewards;
- payment or settlement;
- lending or disbursement;
- custody;
- asset tokenization;
- oracle ingestion;
- upgradeability.

`TradeProofContribution` and `TradeProofToken` are separate future contracts. Their state must not change whether a Passport digest is valid, current, revoked, or superseded.
