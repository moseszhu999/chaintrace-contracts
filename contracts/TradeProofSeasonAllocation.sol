// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofContribution } from "./TradeProofContribution.sol";
import { TradeProofToken } from "./TradeProofToken.sol";

/// @title TradeProof Season Allocation
/// @notice Distributes pre-funded TPROOF from closed-season Proof Points using an auditable Merkle dataset.
/// @dev The square-root allocation is calculated offchain from public closed-season data. This contract
///      verifies the published root, final onchain points snapshot, funding, delay, and one claim per wallet.
contract TradeProofSeasonAllocation {
    uint64 public constant CLAIM_DELAY = 7 days;
    uint32 public constant MINIMUM_ELIGIBILITY_POINTS = 25;
    uint256 public constant GENESIS_PROOF_POOL = 10_000_000 * 1e18;
    uint256 public constant MAX_COMMUNITY_ALLOCATION = 450_000_000 * 1e18;

    bytes32 public constant REWARD_PROFILE_HASH =
        keccak256("TPROOF_SQRT_VERIFIED_POINTS_V0_1");
    bytes32 public constant CLAIM_TYPEHASH = keccak256(
        "TradeProofSeasonClaim(uint256 chainId,address allocationContract,uint32 season,uint32 revision,address account,uint256 verifiedPoints,uint256 tokenAmount)"
    );

    enum DistributionState {
        None,
        Proposed,
        Active,
        Completed
    }

    struct Distribution {
        bytes32 merkleRoot;
        bytes32 datasetDigest;
        uint64 proposedAt;
        uint64 claimableAt;
        uint32 revision;
        uint32 leafCount;
        uint256 totalAllocated;
        uint256 fundedAmount;
        uint256 claimedAmount;
        DistributionState state;
    }

    TradeProofToken public immutable token;
    TradeProofContribution public immutable contribution;
    address public immutable publisher;
    address public immutable communityTreasury;

    uint256 public totalCommunityCommitted;
    mapping(uint32 season => uint32 revision) public seasonRevision;
    mapping(uint32 season => Distribution distribution) private distributions;
    mapping(uint32 season => mapping(address account => bool claimed)) public hasClaimed;

    error NotPublisher(address caller);
    error ZeroAddress();
    error ZeroMerkleRoot();
    error ZeroDatasetDigest();
    error ZeroLeafCount();
    error ZeroAllocation();
    error ZeroReasonHash();
    error SeasonNotClosed(uint32 season);
    error DistributionAlreadyExists(uint32 season, DistributionState state);
    error DistributionNotProposed(uint32 season, DistributionState state);
    error DistributionNotActive(uint32 season, DistributionState state);
    error GenesisPoolMismatch(uint256 supplied, uint256 required);
    error CommunityAllocationExceeded(uint256 attempted, uint256 maximum);
    error ClaimDelayActive(uint32 season, uint64 claimableAt);
    error DistributionNotFullyFunded(uint32 season, uint256 funded, uint256 required);
    error AlreadyClaimed(uint32 season, address account);
    error IneligiblePoints(address account, uint256 points, uint256 minimum);
    error PointsSnapshotMismatch(address account, uint256 supplied, uint256 onchainPoints);
    error InvalidMerkleProof(uint32 season, address account);
    error ClaimAllocationExceeded(uint32 season, uint256 attempted, uint256 maximum);
    error TokenTransferFailed();

    event SeasonProposed(
        uint32 indexed season,
        uint32 indexed revision,
        bytes32 indexed merkleRoot,
        bytes32 datasetDigest,
        bytes32 rewardProfileHash,
        uint32 leafCount,
        uint256 totalAllocated,
        uint64 claimableAt
    );
    event SeasonFunded(
        uint32 indexed season,
        uint32 indexed revision,
        address indexed treasury,
        uint256 amount,
        uint256 totalFunded
    );
    event SeasonActivated(
        uint32 indexed season, uint32 indexed revision, bytes32 indexed merkleRoot, uint64 activatedAt
    );
    event SeasonCancelled(
        uint32 indexed season,
        uint32 indexed revision,
        bytes32 indexed reasonHash,
        uint256 refundedAmount
    );
    event Claimed(
        uint32 indexed season,
        uint32 indexed revision,
        address indexed account,
        uint256 verifiedPoints,
        uint256 tokenAmount
    );
    event SeasonCompleted(
        uint32 indexed season, uint32 indexed revision, uint256 totalClaimed, uint64 completedAt
    );

    modifier onlyPublisher() {
        if (msg.sender != publisher) revert NotPublisher(msg.sender);
        _;
    }

    constructor(
        TradeProofToken token_,
        TradeProofContribution contribution_,
        address publisher_,
        address communityTreasury_
    ) {
        if (
            address(token_) == address(0) || address(contribution_) == address(0)
                || publisher_ == address(0) || communityTreasury_ == address(0)
        ) {
            revert ZeroAddress();
        }
        token = token_;
        contribution = contribution_;
        publisher = publisher_;
        communityTreasury = communityTreasury_;
    }

    function getDistribution(uint32 season) external view returns (Distribution memory) {
        return distributions[season];
    }

    /// @notice Publish one immutable candidate dataset for a closed contribution season.
    /// @dev A proposed distribution may be cancelled and republished before activation.
    function proposeSeason(
        uint32 season,
        bytes32 merkleRoot,
        bytes32 datasetDigest,
        uint32 leafCount,
        uint256 totalAllocated
    ) external onlyPublisher {
        if (!contribution.seasonClosed(season)) revert SeasonNotClosed(season);
        DistributionState currentState = distributions[season].state;
        if (currentState != DistributionState.None) {
            revert DistributionAlreadyExists(season, currentState);
        }
        if (merkleRoot == bytes32(0)) revert ZeroMerkleRoot();
        if (datasetDigest == bytes32(0)) revert ZeroDatasetDigest();
        if (leafCount == 0) revert ZeroLeafCount();
        if (totalAllocated == 0) revert ZeroAllocation();
        if (season == 0 && totalAllocated != GENESIS_PROOF_POOL) {
            revert GenesisPoolMismatch(totalAllocated, GENESIS_PROOF_POOL);
        }
        if (totalAllocated > MAX_COMMUNITY_ALLOCATION) {
            revert CommunityAllocationExceeded(totalAllocated, MAX_COMMUNITY_ALLOCATION);
        }

        uint32 revision = seasonRevision[season] + 1;
        seasonRevision[season] = revision;
        uint64 proposedAt = uint64(block.timestamp);
        uint64 claimableAt = proposedAt + CLAIM_DELAY;
        distributions[season] = Distribution({
            merkleRoot: merkleRoot,
            datasetDigest: datasetDigest,
            proposedAt: proposedAt,
            claimableAt: claimableAt,
            revision: revision,
            leafCount: leafCount,
            totalAllocated: totalAllocated,
            fundedAmount: 0,
            claimedAmount: 0,
            state: DistributionState.Proposed
        });

        emit SeasonProposed(
            season,
            revision,
            merkleRoot,
            datasetDigest,
            REWARD_PROFILE_HASH,
            leafCount,
            totalAllocated,
            claimableAt
        );
    }

    /// @notice Pull the exact proposed pool from the immutable community treasury after approval.
    function fundSeason(uint32 season) external onlyPublisher returns (uint256 amount) {
        Distribution storage distribution = distributions[season];
        if (distribution.state != DistributionState.Proposed) {
            revert DistributionNotProposed(season, distribution.state);
        }
        amount = distribution.totalAllocated - distribution.fundedAmount;
        if (amount == 0) revert ZeroAllocation();
        uint256 attemptedCommitment = totalCommunityCommitted + amount;
        if (attemptedCommitment > MAX_COMMUNITY_ALLOCATION) {
            revert CommunityAllocationExceeded(attemptedCommitment, MAX_COMMUNITY_ALLOCATION);
        }

        distribution.fundedAmount += amount;
        totalCommunityCommitted = attemptedCommitment;
        if (!token.transferFrom(communityTreasury, address(this), amount)) {
            revert TokenTransferFailed();
        }
        emit SeasonFunded(
            season,
            distribution.revision,
            communityTreasury,
            amount,
            distribution.fundedAmount
        );
    }

    /// @notice Activate the immutable root after the seven-day review delay and full funding.
    function activateSeason(uint32 season) external {
        Distribution storage distribution = distributions[season];
        if (distribution.state != DistributionState.Proposed) {
            revert DistributionNotProposed(season, distribution.state);
        }
        if (block.timestamp < distribution.claimableAt) {
            revert ClaimDelayActive(season, distribution.claimableAt);
        }
        if (distribution.fundedAmount != distribution.totalAllocated) {
            revert DistributionNotFullyFunded(
                season, distribution.fundedAmount, distribution.totalAllocated
            );
        }
        distribution.state = DistributionState.Active;
        emit SeasonActivated(
            season, distribution.revision, distribution.merkleRoot, uint64(block.timestamp)
        );
    }

    /// @notice Cancel a proposal before activation and return its exact funding to the treasury.
    function cancelProposedSeason(uint32 season, bytes32 reasonHash) external onlyPublisher {
        if (reasonHash == bytes32(0)) revert ZeroReasonHash();
        Distribution memory distribution = distributions[season];
        if (distribution.state != DistributionState.Proposed) {
            revert DistributionNotProposed(season, distribution.state);
        }

        uint256 refundAmount = distribution.fundedAmount;
        delete distributions[season];
        if (refundAmount != 0) {
            totalCommunityCommitted -= refundAmount;
            if (!token.transfer(communityTreasury, refundAmount)) revert TokenTransferFailed();
        }
        emit SeasonCancelled(season, distribution.revision, reasonHash, refundAmount);
    }

    /// @notice Claim a published allocation. Any relayer may submit; tokens always reach `account`.
    function claim(
        uint32 season,
        address account,
        uint256 verifiedPointsSnapshot,
        uint256 tokenAmount,
        bytes32[] calldata merkleProof
    ) external {
        if (account == address(0)) revert ZeroAddress();
        if (tokenAmount == 0) revert ZeroAllocation();
        Distribution storage distribution = distributions[season];
        if (distribution.state != DistributionState.Active) {
            revert DistributionNotActive(season, distribution.state);
        }
        if (hasClaimed[season][account]) revert AlreadyClaimed(season, account);

        uint256 onchainPoints = contribution.verifiedPoints(season, account);
        if (onchainPoints < MINIMUM_ELIGIBILITY_POINTS) {
            revert IneligiblePoints(account, onchainPoints, MINIMUM_ELIGIBILITY_POINTS);
        }
        if (verifiedPointsSnapshot != onchainPoints) {
            revert PointsSnapshotMismatch(account, verifiedPointsSnapshot, onchainPoints);
        }

        bytes32 leaf = claimLeaf(
            season,
            distribution.revision,
            account,
            verifiedPointsSnapshot,
            tokenAmount
        );
        if (!_verifyMerkleProof(merkleProof, distribution.merkleRoot, leaf)) {
            revert InvalidMerkleProof(season, account);
        }

        uint256 attemptedClaimed = distribution.claimedAmount + tokenAmount;
        if (attemptedClaimed > distribution.totalAllocated) {
            revert ClaimAllocationExceeded(season, attemptedClaimed, distribution.totalAllocated);
        }

        hasClaimed[season][account] = true;
        distribution.claimedAmount = attemptedClaimed;
        if (attemptedClaimed == distribution.totalAllocated) {
            distribution.state = DistributionState.Completed;
        }
        if (!token.transfer(account, tokenAmount)) revert TokenTransferFailed();

        emit Claimed(
            season,
            distribution.revision,
            account,
            verifiedPointsSnapshot,
            tokenAmount
        );
        if (attemptedClaimed == distribution.totalAllocated) {
            emit SeasonCompleted(
                season, distribution.revision, attemptedClaimed, uint64(block.timestamp)
            );
        }
    }

    function claimLeaf(
        uint32 season,
        uint32 revision,
        address account,
        uint256 verifiedPointsSnapshot,
        uint256 tokenAmount
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                block.chainid,
                address(this),
                season,
                revision,
                account,
                verifiedPointsSnapshot,
                tokenAmount
            )
        );
    }

    function verifyClaim(
        uint32 season,
        address account,
        uint256 verifiedPointsSnapshot,
        uint256 tokenAmount,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        Distribution memory distribution = distributions[season];
        if (distribution.state != DistributionState.Active) return false;
        bytes32 leaf = claimLeaf(
            season,
            distribution.revision,
            account,
            verifiedPointsSnapshot,
            tokenAmount
        );
        return _verifyMerkleProof(merkleProof, distribution.merkleRoot, leaf);
    }

    function _verifyMerkleProof(bytes32[] calldata proof, bytes32 root, bytes32 leaf)
        private
        pure
        returns (bool)
    {
        bytes32 computed = leaf;
        for (uint256 index = 0; index < proof.length; index++) {
            bytes32 sibling = proof[index];
            computed = computed < sibling
                ? keccak256(abi.encodePacked(computed, sibling))
                : keccak256(abi.encodePacked(sibling, computed));
        }
        return computed == root;
    }
}
