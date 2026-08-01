// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofRegistry } from "./TradeProofRegistry.sol";

/// @title TradeProofContribution
/// @notice Records non-transferable contribution receipts and seasonal Proof Points.
/// @dev This contract does not mint or distribute TPROOF and cannot change Registry validity.
contract TradeProofContribution {
    uint64 public constant SEASON_LENGTH = 90 days;
    uint64 public constant REVIEW_DELAY = 30 days;
    uint64 public constant APPEAL_WINDOW = 14 days;
    uint64 public constant CLAIM_DELAY = 7 days;
    uint64 public constant VIRAL_REUSE_WINDOW = 30 days;

    uint32 public constant MINIMUM_ELIGIBILITY_POINTS = 25;
    uint32 public constant AUTOMATIC_POINTS_PER_WALLET_PER_DAY = 200;
    uint32 public constant AUTOMATIC_POINTS_PER_WALLET_PAIR_PER_SEASON = 300;

    enum Track {
        AutomaticUsage,
        ReviewedPublicGoods
    }

    enum ContributionKind {
        AnchorUniquePassport,
        IndependentResponsePassportIssuer,
        IndependentResponseResponder,
        ThirdDistinctResponderRole,
        ViralReuseInviter,
        ViralReuseCreator,
        RepeatTradeUsage,
        AcceptedStandardChange,
        ProductionConnectorOrAgentIntegration,
        SecurityFindingOrFix,
        VerifiedRepeatAdoptionCase,
        DocumentationTranslationOrEducation
    }

    enum ReceiptState {
        None,
        PendingReview,
        PendingDelay,
        Finalized,
        Excluded,
        Revoked
    }

    struct Receipt {
        address beneficiary;
        address reviewer;
        uint64 recordedAt;
        uint64 eligibleAt;
        uint64 finalizedAt;
        uint64 excludedAt;
        uint32 season;
        uint32 points;
        uint32 requestedPoints;
        Track track;
        ContributionKind kind;
        ReceiptState state;
        bytes32 primaryDigest;
        bytes32 secondaryDigest;
        bytes32 decisionHash;
        bytes32 reasonHash;
        bytes32 appealDigest;
    }

    TradeProofRegistry public immutable registry;
    uint64 public immutable genesisTimestamp;

    address public owner;
    mapping(address account => bool allowed) public reviewers;
    mapping(bytes32 receiptId => Receipt receipt) private receipts;
    mapping(uint32 season => mapping(address beneficiary => uint256 points)) public verifiedPoints;
    mapping(uint32 season => uint256 points) public totalVerifiedPoints;
    mapping(uint256 day => mapping(address beneficiary => uint32 points)) public dailyAutomaticPoints;
    mapping(uint32 season => mapping(bytes32 pairKey => uint32 points)) public seasonalPairPoints;
    mapping(bytes32 responseDigest => bytes32 roleHash) public responseRoleHash;
    mapping(uint32 season => bool closed) public seasonClosed;

    error NotOwner(address caller);
    error NotReviewer(address caller);
    error ZeroAddress();
    error ZeroDigest();
    error ZeroRoleHash();
    error ZeroDecisionHash();
    error ReceiptAlreadyExists(bytes32 receiptId);
    error UnknownReceipt(bytes32 receiptId);
    error WrongReceiptState(bytes32 receiptId, ReceiptState state);
    error NotBeneficiary(bytes32 receiptId, address caller);
    error ArtifactNotCurrent(bytes32 digest);
    error PassportRequired(bytes32 digest);
    error ResponseRequired(bytes32 digest);
    error NotArtifactIssuer(bytes32 digest, address caller);
    error SelfResponseNotEligible(bytes32 responseDigest);
    error SubjectMismatch(bytes32 responseDigest, bytes32 passportDigest);
    error DuplicateParticipant(address participant);
    error DuplicateRole(bytes32 roleHash);
    error RoleAlreadyDeclared(bytes32 responseDigest);
    error RoleNotDeclared(bytes32 responseDigest);
    error ViralReuseWindowMissed(bytes32 responseDigest, bytes32 passportDigest);
    error DistinctLineagesRequired();
    error ActorDidNotParticipate(address actor, bytes32 responseDigest);
    error SeasonDistanceExceeded(uint32 firstSeason, uint32 secondSeason);
    error DailyAutomaticCapExceeded(address beneficiary, uint32 attemptedPoints);
    error PairSeasonCapExceeded(bytes32 pairKey, uint32 attemptedPoints);
    error PointsOutOfRange(uint32 points, uint32 minimum, uint32 maximum);
    error ReviewDelayActive(bytes32 receiptId, uint64 eligibleAt);
    error AppealWindowClosed(bytes32 receiptId);
    error AppealRequired(bytes32 receiptId);
    error SeasonAlreadyClosed(uint32 season);
    error SeasonStillActive(uint32 season, uint64 closableAt);
    error ClosedSeason(uint32 season);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ReviewerSet(address indexed reviewer, bool allowed);
    event ResponseRoleDeclared(bytes32 indexed responseDigest, address indexed responder, bytes32 roleHash);
    event ReceiptRecorded(
        bytes32 indexed receiptId,
        address indexed beneficiary,
        ContributionKind indexed kind,
        Track track,
        uint32 season,
        uint32 points,
        bytes32 primaryDigest,
        bytes32 secondaryDigest,
        uint64 eligibleAt
    );
    event ReceiptReviewed(
        bytes32 indexed receiptId,
        address indexed reviewer,
        bool approved,
        uint32 points,
        bytes32 decisionHash
    );
    event ReceiptFinalized(
        bytes32 indexed receiptId, address indexed beneficiary, uint32 indexed season, uint32 points
    );
    event ReceiptExcluded(bytes32 indexed receiptId, address indexed reviewer, bytes32 reasonHash);
    event ReceiptRevoked(bytes32 indexed receiptId, address indexed reviewer, bytes32 reasonHash);
    event ReceiptAppealed(bytes32 indexed receiptId, address indexed beneficiary, bytes32 appealDigest);
    event AppealResolved(
        bytes32 indexed receiptId,
        address indexed reviewer,
        bool restored,
        uint32 restoredPoints,
        bytes32 decisionHash
    );
    event SeasonClosed(uint32 indexed season, uint256 totalPoints, uint64 closedAt);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyReviewer() {
        if (!reviewers[msg.sender]) revert NotReviewer(msg.sender);
        _;
    }

    constructor(TradeProofRegistry registry_) {
        if (address(registry_) == address(0)) revert ZeroAddress();
        registry = registry_;
        genesisTimestamp = uint64(block.timestamp);
        owner = msg.sender;
        reviewers[msg.sender] = true;
        emit OwnershipTransferred(address(0), msg.sender);
        emit ReviewerSet(msg.sender, true);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function setReviewer(address reviewer, bool allowed) external onlyOwner {
        if (reviewer == address(0)) revert ZeroAddress();
        reviewers[reviewer] = allowed;
        emit ReviewerSet(reviewer, allowed);
    }

    function currentSeason() public view returns (uint32) {
        return seasonAt(uint64(block.timestamp));
    }

    function seasonAt(uint64 timestamp) public view returns (uint32) {
        if (timestamp <= genesisTimestamp) return 0;
        return uint32((timestamp - genesisTimestamp) / SEASON_LENGTH);
    }

    function seasonEndTimestamp(uint32 season) public view returns (uint64) {
        return genesisTimestamp + (uint64(season) + 1) * SEASON_LENGTH;
    }

    function seasonClosableAt(uint32 season) public view returns (uint64) {
        return seasonEndTimestamp(season) + REVIEW_DELAY + APPEAL_WINDOW;
    }

    function getReceipt(bytes32 receiptId) external view returns (Receipt memory) {
        Receipt memory receipt = receipts[receiptId];
        if (receipt.state == ReceiptState.None) revert UnknownReceipt(receiptId);
        return receipt;
    }

    function isSeasonEligible(uint32 season, address beneficiary) external view returns (bool) {
        return verifiedPoints[season][beneficiary] >= MINIMUM_ELIGIBILITY_POINTS;
    }

    /// @notice Record the five-point unique-Passport contribution for its issuer.
    function recordUniquePassport(bytes32 passportDigest) external returns (bytes32 receiptId) {
        TradeProofRegistry.Anchor memory passport = _currentPassport(passportDigest);
        if (passport.issuer != msg.sender) revert NotArtifactIssuer(passportDigest, msg.sender);

        bytes32 eventKey = keccak256(abi.encode(ContributionKind.AnchorUniquePassport, passportDigest));
        receiptId = _recordAutomatic(
            eventKey,
            passport.issuer,
            ContributionKind.AnchorUniquePassport,
            5,
            passportDigest,
            bytes32(0)
        );
    }

    /// @notice Record deterministic points for an independent Response and its Passport issuer.
    function recordIndependentResponse(bytes32 responseDigest)
        external
        returns (bytes32 issuerReceiptId, bytes32 responderReceiptId)
    {
        TradeProofRegistry.Anchor memory response = _currentResponse(responseDigest);
        TradeProofRegistry.Anchor memory passport = _currentPassport(response.subjectDigest);
        if (response.issuer == passport.issuer) revert SelfResponseNotEligible(responseDigest);

        uint32 season = currentSeason();
        _consumePairPoints(passport.issuer, response.issuer, season, 30);
        bytes32 eventKey = keccak256(
            abi.encode(ContributionKind.IndependentResponseResponder, responseDigest, response.subjectDigest)
        );

        issuerReceiptId = _recordAutomatic(
            eventKey,
            passport.issuer,
            ContributionKind.IndependentResponsePassportIssuer,
            10,
            responseDigest,
            response.subjectDigest
        );
        responderReceiptId = _recordAutomatic(
            eventKey,
            response.issuer,
            ContributionKind.IndependentResponseResponder,
            20,
            responseDigest,
            response.subjectDigest
        );
    }

    /// @notice Let a Response issuer publish the self-declared role hash used by the three-role rule.
    function declareResponseRole(bytes32 responseDigest, bytes32 roleHash) external {
        if (roleHash == bytes32(0)) revert ZeroRoleHash();
        TradeProofRegistry.Anchor memory response = _currentResponse(responseDigest);
        if (response.issuer != msg.sender) revert NotArtifactIssuer(responseDigest, msg.sender);
        if (responseRoleHash[responseDigest] != bytes32(0)) revert RoleAlreadyDeclared(responseDigest);
        responseRoleHash[responseDigest] = roleHash;
        emit ResponseRoleDeclared(responseDigest, msg.sender, roleHash);
    }

    /// @notice Record the Passport-issuer reward for three distinct responders and role hashes.
    function recordThirdDistinctResponderRole(
        bytes32 passportDigest,
        bytes32 responseDigestA,
        bytes32 responseDigestB,
        bytes32 responseDigestC
    ) external returns (bytes32 receiptId) {
        TradeProofRegistry.Anchor memory passport = _currentPassport(passportDigest);
        TradeProofRegistry.Anchor memory responseA = _responseForPassport(responseDigestA, passportDigest);
        TradeProofRegistry.Anchor memory responseB = _responseForPassport(responseDigestB, passportDigest);
        TradeProofRegistry.Anchor memory responseC = _responseForPassport(responseDigestC, passportDigest);

        if (responseA.issuer == passport.issuer) revert SelfResponseNotEligible(responseDigestA);
        if (responseB.issuer == passport.issuer) revert SelfResponseNotEligible(responseDigestB);
        if (responseC.issuer == passport.issuer) revert SelfResponseNotEligible(responseDigestC);
        if (responseA.issuer == responseB.issuer) revert DuplicateParticipant(responseA.issuer);
        if (responseA.issuer == responseC.issuer) revert DuplicateParticipant(responseA.issuer);
        if (responseB.issuer == responseC.issuer) revert DuplicateParticipant(responseB.issuer);

        bytes32 roleA = responseRoleHash[responseDigestA];
        bytes32 roleB = responseRoleHash[responseDigestB];
        bytes32 roleC = responseRoleHash[responseDigestC];
        if (roleA == bytes32(0)) revert RoleNotDeclared(responseDigestA);
        if (roleB == bytes32(0)) revert RoleNotDeclared(responseDigestB);
        if (roleC == bytes32(0)) revert RoleNotDeclared(responseDigestC);
        if (roleA == roleB) revert DuplicateRole(roleA);
        if (roleA == roleC) revert DuplicateRole(roleA);
        if (roleB == roleC) revert DuplicateRole(roleB);

        (bytes32 first, bytes32 second, bytes32 third) =
            _sortThree(responseDigestA, responseDigestB, responseDigestC);
        bytes32 eventKey = keccak256(
            abi.encode(ContributionKind.ThirdDistinctResponderRole, passportDigest, first, second, third)
        );
        receiptId = _recordAutomatic(
            eventKey,
            passport.issuer,
            ContributionKind.ThirdDistinctResponderRole,
            30,
            passportDigest,
            keccak256(abi.encode(first, second, third))
        );
    }

    /// @notice Record the 50/25 viral-reuse reward when a responder creates a new Passport in 30 days.
    function recordViralReuse(bytes32 responseDigest, bytes32 newPassportDigest)
        external
        returns (bytes32 inviterReceiptId, bytes32 creatorReceiptId)
    {
        TradeProofRegistry.Anchor memory response = _currentResponse(responseDigest);
        TradeProofRegistry.Anchor memory sourcePassport = _currentPassport(response.subjectDigest);
        TradeProofRegistry.Anchor memory newPassport = _currentPassport(newPassportDigest);

        if (response.issuer != newPassport.issuer) {
            revert NotArtifactIssuer(newPassportDigest, response.issuer);
        }
        if (newPassportDigest == response.subjectDigest) revert DistinctLineagesRequired();
        if (
            newPassport.anchoredAt < response.anchoredAt
                || newPassport.anchoredAt > response.anchoredAt + VIRAL_REUSE_WINDOW
        ) {
            revert ViralReuseWindowMissed(responseDigest, newPassportDigest);
        }
        if (sourcePassport.issuer == newPassport.issuer) revert SelfResponseNotEligible(responseDigest);

        uint32 season = currentSeason();
        _consumePairPoints(sourcePassport.issuer, newPassport.issuer, season, 75);
        bytes32 eventKey = keccak256(
            abi.encode(ContributionKind.ViralReuseCreator, responseDigest, newPassportDigest)
        );

        inviterReceiptId = _recordAutomatic(
            eventKey,
            sourcePassport.issuer,
            ContributionKind.ViralReuseInviter,
            50,
            responseDigest,
            newPassportDigest
        );
        creatorReceiptId = _recordAutomatic(
            eventKey,
            newPassport.issuer,
            ContributionKind.ViralReuseCreator,
            25,
            responseDigest,
            newPassportDigest
        );
    }

    /// @notice Record repeat use across two distinct Passport lineages with independent Responses.
    function recordRepeatTradeUsage(
        address actor,
        bytes32 firstResponseDigest,
        bytes32 secondResponseDigest
    ) external returns (bytes32 receiptId) {
        if (actor == address(0)) revert ZeroAddress();
        TradeProofRegistry.Anchor memory firstResponse = _currentResponse(firstResponseDigest);
        TradeProofRegistry.Anchor memory secondResponse = _currentResponse(secondResponseDigest);
        if (firstResponse.subjectDigest == secondResponse.subjectDigest) revert DistinctLineagesRequired();

        TradeProofRegistry.Anchor memory firstPassport = _currentPassport(firstResponse.subjectDigest);
        TradeProofRegistry.Anchor memory secondPassport = _currentPassport(secondResponse.subjectDigest);
        if (firstResponse.issuer == firstPassport.issuer) {
            revert SelfResponseNotEligible(firstResponseDigest);
        }
        if (secondResponse.issuer == secondPassport.issuer) {
            revert SelfResponseNotEligible(secondResponseDigest);
        }
        if (actor != firstResponse.issuer && actor != firstPassport.issuer) {
            revert ActorDidNotParticipate(actor, firstResponseDigest);
        }
        if (actor != secondResponse.issuer && actor != secondPassport.issuer) {
            revert ActorDidNotParticipate(actor, secondResponseDigest);
        }

        uint32 firstSeason = seasonAt(firstResponse.anchoredAt);
        uint32 secondSeason = seasonAt(secondResponse.anchoredAt);
        uint32 distance = firstSeason > secondSeason ? firstSeason - secondSeason : secondSeason - firstSeason;
        if (distance > 1) revert SeasonDistanceExceeded(firstSeason, secondSeason);

        (bytes32 first, bytes32 second) = firstResponseDigest < secondResponseDigest
            ? (firstResponseDigest, secondResponseDigest)
            : (secondResponseDigest, firstResponseDigest);
        bytes32 eventKey =
            keccak256(abi.encode(ContributionKind.RepeatTradeUsage, actor, first, second));
        receiptId = _recordAutomatic(
            eventKey,
            actor,
            ContributionKind.RepeatTradeUsage,
            20,
            first,
            second
        );
    }

    /// @notice Submit a high-value public-goods contribution for governed review.
    function submitPublicGoodsContribution(
        ContributionKind kind,
        bytes32 evidenceDigest,
        uint32 requestedPoints
    ) external returns (bytes32 receiptId) {
        if (evidenceDigest == bytes32(0)) revert ZeroDigest();
        (uint32 minimum, uint32 maximum) = _publicGoodsRange(kind);
        if (requestedPoints < minimum || requestedPoints > maximum) {
            revert PointsOutOfRange(requestedPoints, minimum, maximum);
        }

        uint32 season = currentSeason();
        if (seasonClosed[season]) revert ClosedSeason(season);
        receiptId = keccak256(abi.encode(kind, msg.sender, evidenceDigest));
        if (receipts[receiptId].state != ReceiptState.None) revert ReceiptAlreadyExists(receiptId);

        uint64 recordedAt = uint64(block.timestamp);
        receipts[receiptId] = Receipt({
            beneficiary: msg.sender,
            reviewer: address(0),
            recordedAt: recordedAt,
            eligibleAt: 0,
            finalizedAt: 0,
            excludedAt: 0,
            season: season,
            points: requestedPoints,
            requestedPoints: requestedPoints,
            track: Track.ReviewedPublicGoods,
            kind: kind,
            state: ReceiptState.PendingReview,
            primaryDigest: evidenceDigest,
            secondaryDigest: bytes32(0),
            decisionHash: bytes32(0),
            reasonHash: bytes32(0),
            appealDigest: bytes32(0)
        });

        emit ReceiptRecorded(
            receiptId,
            msg.sender,
            kind,
            Track.ReviewedPublicGoods,
            season,
            requestedPoints,
            evidenceDigest,
            bytes32(0),
            0
        );
    }

    /// @notice Approve or reject a reviewed public-goods submission.
    function reviewPublicGoodsContribution(
        bytes32 receiptId,
        bool approved,
        uint32 approvedPoints,
        bytes32 decisionHash
    ) external onlyReviewer {
        if (decisionHash == bytes32(0)) revert ZeroDecisionHash();
        Receipt storage receipt = _receipt(receiptId);
        if (receipt.state != ReceiptState.PendingReview) {
            revert WrongReceiptState(receiptId, receipt.state);
        }
        if (seasonClosed[receipt.season]) revert ClosedSeason(receipt.season);

        receipt.reviewer = msg.sender;
        receipt.decisionHash = decisionHash;
        if (!approved) {
            receipt.state = ReceiptState.Excluded;
            receipt.excludedAt = uint64(block.timestamp);
            receipt.reasonHash = decisionHash;
            emit ReceiptReviewed(receiptId, msg.sender, false, 0, decisionHash);
            emit ReceiptExcluded(receiptId, msg.sender, decisionHash);
            return;
        }

        (uint32 minimum, uint32 maximum) = _publicGoodsRange(receipt.kind);
        if (
            approvedPoints < minimum || approvedPoints > maximum
                || approvedPoints > receipt.requestedPoints
        ) {
            revert PointsOutOfRange(approvedPoints, minimum, maximum);
        }
        receipt.points = approvedPoints;
        receipt.state = ReceiptState.PendingDelay;
        receipt.eligibleAt = uint64(block.timestamp) + REVIEW_DELAY;
        emit ReceiptReviewed(receiptId, msg.sender, true, approvedPoints, decisionHash);
    }

    /// @notice Finalize an eligible receipt and add its points to the recorded season.
    function finalizeReceipt(bytes32 receiptId) external {
        Receipt storage receipt = _receipt(receiptId);
        if (receipt.state != ReceiptState.PendingDelay) {
            revert WrongReceiptState(receiptId, receipt.state);
        }
        if (seasonClosed[receipt.season]) revert ClosedSeason(receipt.season);
        if (block.timestamp < receipt.eligibleAt) {
            revert ReviewDelayActive(receiptId, receipt.eligibleAt);
        }

        receipt.state = ReceiptState.Finalized;
        receipt.finalizedAt = uint64(block.timestamp);
        verifiedPoints[receipt.season][receipt.beneficiary] += receipt.points;
        totalVerifiedPoints[receipt.season] += receipt.points;
        emit ReceiptFinalized(receiptId, receipt.beneficiary, receipt.season, receipt.points);
    }

    /// @notice Exclude a pending receipt during anti-Sybil or quality review.
    function excludeReceipt(bytes32 receiptId, bytes32 reasonHash) external onlyReviewer {
        if (reasonHash == bytes32(0)) revert ZeroDecisionHash();
        Receipt storage receipt = _receipt(receiptId);
        if (
            receipt.state != ReceiptState.PendingDelay && receipt.state != ReceiptState.PendingReview
        ) {
            revert WrongReceiptState(receiptId, receipt.state);
        }
        if (seasonClosed[receipt.season]) revert ClosedSeason(receipt.season);
        receipt.state = ReceiptState.Excluded;
        receipt.reviewer = msg.sender;
        receipt.excludedAt = uint64(block.timestamp);
        receipt.reasonHash = reasonHash;
        emit ReceiptExcluded(receiptId, msg.sender, reasonHash);
    }

    /// @notice Revoke a finalized receipt before the season is closed and subtract its points.
    function revokeReceipt(bytes32 receiptId, bytes32 reasonHash) external onlyReviewer {
        if (reasonHash == bytes32(0)) revert ZeroDecisionHash();
        Receipt storage receipt = _receipt(receiptId);
        if (receipt.state != ReceiptState.Finalized) {
            revert WrongReceiptState(receiptId, receipt.state);
        }
        if (seasonClosed[receipt.season]) revert ClosedSeason(receipt.season);

        receipt.state = ReceiptState.Revoked;
        receipt.reviewer = msg.sender;
        receipt.reasonHash = reasonHash;
        verifiedPoints[receipt.season][receipt.beneficiary] -= receipt.points;
        totalVerifiedPoints[receipt.season] -= receipt.points;
        emit ReceiptRevoked(receiptId, msg.sender, reasonHash);
    }

    /// @notice Appeal an excluded receipt within fourteen days.
    function appealReceipt(bytes32 receiptId, bytes32 appealDigest) external {
        if (appealDigest == bytes32(0)) revert ZeroDigest();
        Receipt storage receipt = _receipt(receiptId);
        if (receipt.state != ReceiptState.Excluded) {
            revert WrongReceiptState(receiptId, receipt.state);
        }
        if (receipt.beneficiary != msg.sender) revert NotBeneficiary(receiptId, msg.sender);
        if (block.timestamp > receipt.excludedAt + APPEAL_WINDOW) {
            revert AppealWindowClosed(receiptId);
        }
        receipt.appealDigest = appealDigest;
        emit ReceiptAppealed(receiptId, msg.sender, appealDigest);
    }

    /// @notice Resolve an appeal and optionally restore the receipt to delayed review.
    function resolveAppeal(
        bytes32 receiptId,
        bool restored,
        uint32 restoredPoints,
        bytes32 decisionHash
    ) external onlyReviewer {
        if (decisionHash == bytes32(0)) revert ZeroDecisionHash();
        Receipt storage receipt = _receipt(receiptId);
        if (receipt.state != ReceiptState.Excluded) {
            revert WrongReceiptState(receiptId, receipt.state);
        }
        if (receipt.appealDigest == bytes32(0)) revert AppealRequired(receiptId);
        if (seasonClosed[receipt.season]) revert ClosedSeason(receipt.season);

        receipt.reviewer = msg.sender;
        receipt.decisionHash = decisionHash;
        if (restored) {
            if (receipt.track == Track.ReviewedPublicGoods) {
                (uint32 minimum, uint32 maximum) = _publicGoodsRange(receipt.kind);
                if (
                    restoredPoints < minimum || restoredPoints > maximum
                        || restoredPoints > receipt.requestedPoints
                ) {
                    revert PointsOutOfRange(restoredPoints, minimum, maximum);
                }
                receipt.points = restoredPoints;
            } else if (restoredPoints != receipt.points) {
                revert PointsOutOfRange(restoredPoints, receipt.points, receipt.points);
            }
            receipt.state = ReceiptState.PendingDelay;
            receipt.eligibleAt = uint64(block.timestamp) + REVIEW_DELAY;
        }

        emit AppealResolved(receiptId, msg.sender, restored, restoredPoints, decisionHash);
    }

    /// @notice Freeze a season after its review and appeal windows have elapsed.
    function closeSeason(uint32 season) external onlyOwner {
        if (seasonClosed[season]) revert SeasonAlreadyClosed(season);
        uint64 closableAt = seasonClosableAt(season);
        if (block.timestamp < closableAt) revert SeasonStillActive(season, closableAt);
        seasonClosed[season] = true;
        emit SeasonClosed(season, totalVerifiedPoints[season], uint64(block.timestamp));
    }

    function _recordAutomatic(
        bytes32 eventKey,
        address beneficiary,
        ContributionKind kind,
        uint32 points,
        bytes32 primaryDigest,
        bytes32 secondaryDigest
    ) private returns (bytes32 receiptId) {
        uint32 season = currentSeason();
        if (seasonClosed[season]) revert ClosedSeason(season);
        receiptId = keccak256(abi.encode(eventKey, beneficiary, kind));
        if (receipts[receiptId].state != ReceiptState.None) revert ReceiptAlreadyExists(receiptId);

        uint256 day = block.timestamp / 1 days;
        uint32 attemptedDailyPoints = dailyAutomaticPoints[day][beneficiary] + points;
        if (attemptedDailyPoints > AUTOMATIC_POINTS_PER_WALLET_PER_DAY) {
            revert DailyAutomaticCapExceeded(beneficiary, attemptedDailyPoints);
        }
        dailyAutomaticPoints[day][beneficiary] = attemptedDailyPoints;

        uint64 recordedAt = uint64(block.timestamp);
        uint64 eligibleAt = recordedAt + REVIEW_DELAY;
        receipts[receiptId] = Receipt({
            beneficiary: beneficiary,
            reviewer: address(0),
            recordedAt: recordedAt,
            eligibleAt: eligibleAt,
            finalizedAt: 0,
            excludedAt: 0,
            season: season,
            points: points,
            requestedPoints: points,
            track: Track.AutomaticUsage,
            kind: kind,
            state: ReceiptState.PendingDelay,
            primaryDigest: primaryDigest,
            secondaryDigest: secondaryDigest,
            decisionHash: bytes32(0),
            reasonHash: bytes32(0),
            appealDigest: bytes32(0)
        });

        emit ReceiptRecorded(
            receiptId,
            beneficiary,
            kind,
            Track.AutomaticUsage,
            season,
            points,
            primaryDigest,
            secondaryDigest,
            eligibleAt
        );
    }

    function _consumePairPoints(address first, address second, uint32 season, uint32 points) private {
        bytes32 pairKey = _pairKey(first, second);
        uint32 attemptedPoints = seasonalPairPoints[season][pairKey] + points;
        if (attemptedPoints > AUTOMATIC_POINTS_PER_WALLET_PAIR_PER_SEASON) {
            revert PairSeasonCapExceeded(pairKey, attemptedPoints);
        }
        seasonalPairPoints[season][pairKey] = attemptedPoints;
    }

    function _pairKey(address first, address second) private pure returns (bytes32) {
        return first < second ? keccak256(abi.encode(first, second)) : keccak256(abi.encode(second, first));
    }

    function _currentPassport(bytes32 digest)
        private
        view
        returns (TradeProofRegistry.Anchor memory anchor)
    {
        if (digest == bytes32(0)) revert ZeroDigest();
        anchor = registry.getAnchor(digest);
        if (anchor.kind != TradeProofRegistry.ArtifactKind.Passport) revert PassportRequired(digest);
        if (!registry.isCurrent(digest)) revert ArtifactNotCurrent(digest);
    }

    function _currentResponse(bytes32 digest)
        private
        view
        returns (TradeProofRegistry.Anchor memory anchor)
    {
        if (digest == bytes32(0)) revert ZeroDigest();
        anchor = registry.getAnchor(digest);
        if (anchor.kind != TradeProofRegistry.ArtifactKind.Response) revert ResponseRequired(digest);
        if (!registry.isCurrent(digest)) revert ArtifactNotCurrent(digest);
    }

    function _responseForPassport(bytes32 responseDigest, bytes32 passportDigest)
        private
        view
        returns (TradeProofRegistry.Anchor memory response)
    {
        response = _currentResponse(responseDigest);
        if (response.subjectDigest != passportDigest) {
            revert SubjectMismatch(responseDigest, passportDigest);
        }
    }

    function _receipt(bytes32 receiptId) private view returns (Receipt storage receipt) {
        receipt = receipts[receiptId];
        if (receipt.state == ReceiptState.None) revert UnknownReceipt(receiptId);
    }

    function _publicGoodsRange(ContributionKind kind)
        private
        pure
        returns (uint32 minimum, uint32 maximum)
    {
        if (kind == ContributionKind.AcceptedStandardChange) return (500, 3000);
        if (kind == ContributionKind.ProductionConnectorOrAgentIntegration) return (1500, 10000);
        if (kind == ContributionKind.SecurityFindingOrFix) return (500, 15000);
        if (kind == ContributionKind.VerifiedRepeatAdoptionCase) return (1000, 10000);
        if (kind == ContributionKind.DocumentationTranslationOrEducation) return (100, 2000);
        revert PointsOutOfRange(0, 1, 0);
    }

    function _sortThree(bytes32 a, bytes32 b, bytes32 c)
        private
        pure
        returns (bytes32 first, bytes32 second, bytes32 third)
    {
        first = a;
        second = b;
        third = c;
        if (first > second) (first, second) = (second, first);
        if (second > third) (second, third) = (third, second);
        if (first > second) (first, second) = (second, first);
    }
}
