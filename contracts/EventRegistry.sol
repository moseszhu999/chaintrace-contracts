// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ChainTrace Event Registry
/// @notice Minimal registry for linking supply chain events to batch keys and proof IDs.
contract EventRegistry {
    struct SupplyChainEvent {
        address actor;
        bytes32 batchKey;
        string eventType;
        uint256 proofId;
        bytes32 metadataHash;
        uint256 timestamp;
    }

    uint256 public nextEventId = 1;

    mapping(uint256 => SupplyChainEvent) private eventsById;
    mapping(bytes32 => uint256[]) private eventIdsByBatchKey;
    mapping(address => uint256[]) private eventIdsByActor;

    event SupplyChainEventAdded(
        uint256 indexed eventId,
        address indexed actor,
        bytes32 indexed batchKey,
        string eventType,
        uint256 proofId,
        bytes32 metadataHash,
        uint256 timestamp
    );

    error EmptyBatchKey();
    error EmptyEventType();
    error EventNotFound(uint256 eventId);

    /// @notice Add a supply chain event linked to a batch and optional proof.
    /// @param batchKey Deterministic key for a batch/order/shipment/trade object.
    /// @param eventType Event type, such as PRODUCED, INSPECTED, SHIPPED, DELIVERED, ACCEPTED, or REJECTED.
    /// @param proofId Optional proof ID from ProofRegistry. Use 0 if not linked yet.
    /// @param metadataHash Optional hash of extended event metadata.
    /// @return eventId Newly created event identifier.
    function addEvent(
        bytes32 batchKey,
        string calldata eventType,
        uint256 proofId,
        bytes32 metadataHash
    ) external returns (uint256 eventId) {
        if (batchKey == bytes32(0)) revert EmptyBatchKey();
        if (bytes(eventType).length == 0) revert EmptyEventType();

        eventId = nextEventId;
        nextEventId += 1;

        eventsById[eventId] = SupplyChainEvent({
            actor: msg.sender,
            batchKey: batchKey,
            eventType: eventType,
            proofId: proofId,
            metadataHash: metadataHash,
            timestamp: block.timestamp
        });

        eventIdsByBatchKey[batchKey].push(eventId);
        eventIdsByActor[msg.sender].push(eventId);

        emit SupplyChainEventAdded(
            eventId,
            msg.sender,
            batchKey,
            eventType,
            proofId,
            metadataHash,
            block.timestamp
        );
    }

    /// @notice Read an event by ID.
    function getEvent(uint256 eventId) external view returns (SupplyChainEvent memory chainEvent) {
        chainEvent = eventsById[eventId];
        if (chainEvent.actor == address(0)) revert EventNotFound(eventId);
    }

    /// @notice Return all event IDs linked to a batch key.
    function getEventIdsByBatchKey(bytes32 batchKey) external view returns (uint256[] memory) {
        return eventIdsByBatchKey[batchKey];
    }

    /// @notice Return all event IDs submitted by an actor.
    function getEventIdsByActor(address actor) external view returns (uint256[] memory) {
        return eventIdsByActor[actor];
    }

    /// @notice Check whether an event exists.
    function eventExists(uint256 eventId) external view returns (bool) {
        return eventsById[eventId].actor != address(0);
    }
}
