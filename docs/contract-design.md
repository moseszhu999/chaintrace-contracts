# Contract Design

ChainTrace contracts should remain minimal in the early stage.

The first goal is not to create a financial protocol. The first goal is to create an auditable proof anchor.

## Design Boundary

On-chain data should include:

- evidence hash
- proof type
- submitter address
- timestamp
- optional URI or CID
- optional metadata hash
- batch key
- event type

On-chain data should not include:

- full contracts
- full invoices
- personal identity documents
- private customer lists
- bank account details
- sensitive trade secrets

## Contract Set

### ProofRegistry

The first and most important contract.

It records:

- file hash
- proof type
- URI or CID
- metadata hash
- submitter
- timestamp

### BatchRegistry

Creates a flexible batch key from a human-readable batch, order, shipment, or trade ID.

### EventRegistry

Links a supply chain event to a batch key and optional proof ID.

Example event types:

- CREATED
- PRODUCED
- INSPECTED
- SHIPPED
- STORED
- DELIVERED
- ACCEPTED
- REJECTED

## Current Non-goals

The first contract version deliberately avoids:

- token issuance
- yield logic
- lending logic
- payment custody
- stablecoin settlement
- complex role systems
- upgradeability

These can be researched later, after the proof layer is working and reviewed.

## First Integration Target

The first integration target is:

```text
Proof Page MVP → ProofRegistry.registerProof
```

The app should pass:

```text
fileHash
proofType
uri
metadataHash
```

The contract returns:

```text
proofId
transaction hash
block timestamp
```

The proof page can then show these values for public verification.
