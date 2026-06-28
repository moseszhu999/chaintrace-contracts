// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ChainTrace Proof Registry
/// @notice Minimal registry for anchoring evidence hashes on-chain.
/// @dev This contract stores hashes and references, not sensitive business files.
contract ProofRegistry {
    struct Proof {
        address submitter;
        bytes32 fileHash;
        string proofType;
        string uri;
        bytes32 metadataHash;
        uint256 timestamp;
    }

    uint256 public nextProofId = 1;

    mapping(uint256 => Proof) private proofs;
    mapping(bytes32 => uint256[]) private proofIdsByFileHash;
    mapping(address => uint256[]) private proofIdsBySubmitter;

    event ProofRegistered(
        uint256 indexed proofId,
        address indexed submitter,
        bytes32 indexed fileHash,
        string proofType,
        string uri,
        bytes32 metadataHash,
        uint256 timestamp
    );

    error EmptyProofType();
    error EmptyFileHash();
    error ProofNotFound(uint256 proofId);

    /// @notice Register a proof hash and optional off-chain reference.
    /// @param fileHash Hash of the evidence file or canonical evidence payload.
    /// @param proofType Type of proof, such as product, shipment, invoice, inspection, delivery, or acceptance.
    /// @param uri Optional URI or CID pointing to off-chain evidence.
    /// @param metadataHash Optional hash of private or extended metadata.
    /// @return proofId Newly created proof identifier.
    function registerProof(
        bytes32 fileHash,
        string calldata proofType,
        string calldata uri,
        bytes32 metadataHash
    ) external returns (uint256 proofId) {
        if (fileHash == bytes32(0)) revert EmptyFileHash();
        if (bytes(proofType).length == 0) revert EmptyProofType();

        proofId = nextProofId;
        nextProofId += 1;

        proofs[proofId] = Proof({
            submitter: msg.sender,
            fileHash: fileHash,
            proofType: proofType,
            uri: uri,
            metadataHash: metadataHash,
            timestamp: block.timestamp
        });

        proofIdsByFileHash[fileHash].push(proofId);
        proofIdsBySubmitter[msg.sender].push(proofId);

        emit ProofRegistered(
            proofId,
            msg.sender,
            fileHash,
            proofType,
            uri,
            metadataHash,
            block.timestamp
        );
    }

    /// @notice Read a proof by ID.
    function getProof(uint256 proofId) external view returns (Proof memory proof) {
        proof = proofs[proofId];
        if (proof.submitter == address(0)) revert ProofNotFound(proofId);
    }

    /// @notice Return all proof IDs linked to a file hash.
    function getProofIdsByFileHash(bytes32 fileHash) external view returns (uint256[] memory) {
        return proofIdsByFileHash[fileHash];
    }

    /// @notice Return all proof IDs submitted by an address.
    function getProofIdsBySubmitter(address submitter) external view returns (uint256[] memory) {
        return proofIdsBySubmitter[submitter];
    }

    /// @notice Check whether a proof ID exists.
    function proofExists(uint256 proofId) external view returns (bool) {
        return proofs[proofId].submitter != address(0);
    }
}
