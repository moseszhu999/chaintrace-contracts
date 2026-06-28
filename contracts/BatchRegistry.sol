// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ChainTrace Batch Registry
/// @notice Minimal registry for flexible product, shipment, order, or trade batch identifiers.
contract BatchRegistry {
    struct Batch {
        address creator;
        string batchId;
        bytes32 metadataHash;
        uint256 timestamp;
    }

    mapping(bytes32 => Batch) private batches;
    mapping(address => bytes32[]) private batchKeysByCreator;

    event BatchCreated(
        bytes32 indexed batchKey,
        address indexed creator,
        string batchId,
        bytes32 metadataHash,
        uint256 timestamp
    );

    error EmptyBatchId();
    error BatchAlreadyExists(bytes32 batchKey);
    error BatchNotFound(bytes32 batchKey);

    /// @notice Create a batch/order/shipment identifier.
    /// @param batchId Human-readable external batch, shipment, order, or trade identifier.
    /// @param metadataHash Optional hash of extended metadata.
    /// @return batchKey Deterministic key derived from the batch ID.
    function createBatch(
        string calldata batchId,
        bytes32 metadataHash
    ) external returns (bytes32 batchKey) {
        if (bytes(batchId).length == 0) revert EmptyBatchId();

        batchKey = keccak256(abi.encodePacked(batchId));
        if (batches[batchKey].creator != address(0)) revert BatchAlreadyExists(batchKey);

        batches[batchKey] = Batch({
            creator: msg.sender,
            batchId: batchId,
            metadataHash: metadataHash,
            timestamp: block.timestamp
        });

        batchKeysByCreator[msg.sender].push(batchKey);

        emit BatchCreated(batchKey, msg.sender, batchId, metadataHash, block.timestamp);
    }

    /// @notice Read a batch by deterministic key.
    function getBatch(bytes32 batchKey) external view returns (Batch memory batch) {
        batch = batches[batchKey];
        if (batch.creator == address(0)) revert BatchNotFound(batchKey);
    }

    /// @notice Compute the deterministic key for a batch ID.
    function computeBatchKey(string calldata batchId) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(batchId));
    }

    /// @notice Return all batch keys created by an address.
    function getBatchKeysByCreator(address creator) external view returns (bytes32[] memory) {
        return batchKeysByCreator[creator];
    }

    /// @notice Check whether a batch exists.
    function batchExists(bytes32 batchKey) external view returns (bool) {
        return batches[batchKey].creator != address(0);
    }
}
