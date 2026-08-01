# TradeProofRegistry v0.1

Status: testnet-ready implementation candidate.

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
