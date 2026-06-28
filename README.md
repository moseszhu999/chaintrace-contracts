# ChainTrace Contracts

**Minimal smart contracts for the ChainTrace proof layer.**

This repository contains the first smart contract implementation for the ChainTrace Protocol.

The current goal is intentionally narrow:

> Anchor proof hashes on-chain so that product, shipment, invoice, inspection, delivery, and acceptance evidence can be verified later.

## Repositories

- Protocol: https://github.com/moseszhu999/chaintrace-protocol
- App: https://github.com/moseszhu999/chaintrace-app
- Contracts: https://github.com/moseszhu999/chaintrace-contracts

## Current Scope

The first contract set focuses on:

- registering evidence hashes
- associating proofs with proof types
- recording submitter address and timestamp
- emitting events for off-chain indexing
- supporting simple batch and event extensions

## Not Included Yet

- token issuance
- lending logic
- stablecoin settlement
- custody
- financial returns
- on-chain storage of full documents

ChainTrace stores proof references, not sensitive business documents.

## Contracts

### ProofRegistry.sol

Registers a proof hash and metadata reference.

### BatchRegistry.sol

Creates flexible batch/order/shipment identifiers.

### EventRegistry.sol

Links supply chain events to a batch and a proof.

## Install

```bash
npm install
```

## Compile

```bash
npm run compile
```

## Test

```bash
npm test
```

## Deploy Locally

```bash
npm run deploy:local
```

## Design Principle

Proof, not exposure.  
Hashes, not sensitive files.  
Open facts, not platform control.

## Disclaimer

These contracts are experimental and unaudited. They are not financial products, investment contracts, lending systems, or token sale infrastructure.
