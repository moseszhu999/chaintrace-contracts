// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofRegistry } from "../contracts/TradeProofRegistry.sol";
import { TradeProofContribution } from "../contracts/TradeProofContribution.sol";

interface VmContribution {
    function prank(address caller) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 selector) external;
    function warp(uint256 timestamp) external;
}

contract TradeProofContributionTest {
    VmContribution private constant vm =
        VmContribution(address(uint160(uint256(keccak256("hevm cheat code")))));

    TradeProofRegistry private registry;
    TradeProofContribution private contribution;

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant CAROL = address(0xCA401);
    address private constant DAVE = address(0xDA7E);

    bytes32 private constant PASSPORT_A = bytes32(uint256(1));
    bytes32 private constant PASSPORT_B = bytes32(uint256(2));
    bytes32 private constant RESPONSE_A = bytes32(uint256(11));
    bytes32 private constant RESPONSE_B = bytes32(uint256(12));
    bytes32 private constant RESPONSE_C = bytes32(uint256(13));
    bytes32 private constant SCHEMA_HASH = bytes32(uint256(101));
    bytes32 private constant PROFILE_HASH = bytes32(uint256(102));
    bytes32 private constant DECISION_HASH = bytes32(uint256(103));
    bytes32 private constant REASON_HASH = bytes32(uint256(104));
    bytes32 private constant APPEAL_HASH = bytes32(uint256(105));

    function setUp() public {
        registry = new TradeProofRegistry();
        contribution = new TradeProofContribution(registry);
    }

    function testUniquePassportRecordsDelayedNonTransferablePoints() public {
        _anchorPassport(ALICE, PASSPORT_A);

        vm.prank(ALICE);
        bytes32 receiptId = contribution.recordUniquePassport(PASSPORT_A);

        TradeProofContribution.Receipt memory receipt = contribution.getReceipt(receiptId);
        _assertEq(receipt.beneficiary, ALICE, "beneficiary");
        _assertEq(receipt.points, 5, "points");
        _assertEq(
            uint256(receipt.state),
            uint256(TradeProofContribution.ReceiptState.PendingDelay),
            "pending state"
        );
        _assertEq(contribution.verifiedPoints(0, ALICE), 0, "points remain pending");

        vm.expectRevert(TradeProofContribution.ReviewDelayActive.selector);
        contribution.finalizeReceipt(receiptId);

        vm.warp(receipt.eligibleAt);
        contribution.finalizeReceipt(receiptId);
        _assertEq(contribution.verifiedPoints(0, ALICE), 5, "verified points");
    }

    function testUniquePassportRequiresIssuerAndRejectsDuplicateReceipt() public {
        _anchorPassport(ALICE, PASSPORT_A);

        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.NotArtifactIssuer.selector, PASSPORT_A, BOB
            )
        );
        vm.prank(BOB);
        contribution.recordUniquePassport(PASSPORT_A);

        vm.prank(ALICE);
        bytes32 receiptId = contribution.recordUniquePassport(PASSPORT_A);

        vm.expectRevert(
            abi.encodeWithSelector(TradeProofContribution.ReceiptAlreadyExists.selector, receiptId)
        );
        vm.prank(ALICE);
        contribution.recordUniquePassport(PASSPORT_A);
    }

    function testIndependentResponseCreditsBothWalletsAfterDelay() public {
        _anchorPassport(ALICE, PASSPORT_A);
        _anchorResponse(BOB, RESPONSE_A, PASSPORT_A);

        (bytes32 issuerReceiptId, bytes32 responderReceiptId) =
            contribution.recordIndependentResponse(RESPONSE_A);
        TradeProofContribution.Receipt memory issuerReceipt =
            contribution.getReceipt(issuerReceiptId);
        TradeProofContribution.Receipt memory responderReceipt =
            contribution.getReceipt(responderReceiptId);
        _assertEq(issuerReceipt.points, 10, "issuer points");
        _assertEq(responderReceipt.points, 20, "responder points");

        vm.warp(issuerReceipt.eligibleAt);
        contribution.finalizeReceipt(issuerReceiptId);
        contribution.finalizeReceipt(responderReceiptId);
        _assertEq(contribution.verifiedPoints(0, ALICE), 10, "issuer verified");
        _assertEq(contribution.verifiedPoints(0, BOB), 20, "responder verified");
    }

    function testSelfResponseEarnsZeroAndIsRejected() public {
        _anchorPassport(ALICE, PASSPORT_A);
        _anchorResponse(ALICE, RESPONSE_A, PASSPORT_A);

        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.SelfResponseNotEligible.selector, RESPONSE_A
            )
        );
        contribution.recordIndependentResponse(RESPONSE_A);
    }

    function testThirdDistinctResponderRolesCreditPassportIssuer() public {
        _anchorPassport(ALICE, PASSPORT_A);
        _anchorResponse(BOB, RESPONSE_A, PASSPORT_A);
        _anchorResponse(CAROL, RESPONSE_B, PASSPORT_A);
        _anchorResponse(DAVE, RESPONSE_C, PASSPORT_A);
        _declareRole(BOB, RESPONSE_A, bytes32("buyer"));
        _declareRole(CAROL, RESPONSE_B, bytes32("inspection"));
        _declareRole(DAVE, RESPONSE_C, bytes32("logistics"));

        bytes32 receiptId = contribution.recordThirdDistinctResponderRole(
            PASSPORT_A, RESPONSE_C, RESPONSE_A, RESPONSE_B
        );
        TradeProofContribution.Receipt memory receipt = contribution.getReceipt(receiptId);
        _assertEq(receipt.points, 30, "third-role points");
        _assertEq(receipt.beneficiary, ALICE, "passport issuer");

        vm.warp(receipt.eligibleAt);
        contribution.finalizeReceipt(receiptId);
        _assertEq(contribution.verifiedPoints(0, ALICE), 30, "verified role points");
    }

    function testThirdResponderRejectsDuplicateSelfDeclaredRole() public {
        _anchorPassport(ALICE, PASSPORT_A);
        _anchorResponse(BOB, RESPONSE_A, PASSPORT_A);
        _anchorResponse(CAROL, RESPONSE_B, PASSPORT_A);
        _anchorResponse(DAVE, RESPONSE_C, PASSPORT_A);
        _declareRole(BOB, RESPONSE_A, bytes32("buyer"));
        _declareRole(CAROL, RESPONSE_B, bytes32("buyer"));
        _declareRole(DAVE, RESPONSE_C, bytes32("logistics"));

        vm.expectRevert(TradeProofContribution.DuplicateRole.selector);
        contribution.recordThirdDistinctResponderRole(
            PASSPORT_A, RESPONSE_A, RESPONSE_B, RESPONSE_C
        );
    }

    function testViralReuseCreditsInviterAndNewCreator() public {
        _anchorPassport(ALICE, PASSPORT_A);
        _anchorResponse(BOB, RESPONSE_A, PASSPORT_A);
        vm.warp(block.timestamp + 10 days);
        _anchorPassport(BOB, PASSPORT_B);

        (bytes32 inviterReceiptId, bytes32 creatorReceiptId) =
            contribution.recordViralReuse(RESPONSE_A, PASSPORT_B);
        TradeProofContribution.Receipt memory inviterReceipt =
            contribution.getReceipt(inviterReceiptId);
        TradeProofContribution.Receipt memory creatorReceipt =
            contribution.getReceipt(creatorReceiptId);
        _assertEq(inviterReceipt.points, 50, "inviter points");
        _assertEq(creatorReceipt.points, 25, "creator points");

        vm.warp(inviterReceipt.eligibleAt);
        contribution.finalizeReceipt(inviterReceiptId);
        contribution.finalizeReceipt(creatorReceiptId);
        _assertEq(contribution.verifiedPoints(0, ALICE), 50, "inviter verified");
        _assertEq(contribution.verifiedPoints(0, BOB), 25, "creator verified");
    }

    function testViralReuseOutsideThirtyDaysIsRejected() public {
        _anchorPassport(ALICE, PASSPORT_A);
        _anchorResponse(BOB, RESPONSE_A, PASSPORT_A);
        vm.warp(block.timestamp + 31 days);
        _anchorPassport(BOB, PASSPORT_B);

        vm.expectRevert(TradeProofContribution.ViralReuseWindowMissed.selector);
        contribution.recordViralReuse(RESPONSE_A, PASSPORT_B);
    }

    function testRepeatUsageAcrossTwoIndependentLineagesCreditsActor() public {
        _anchorPassport(ALICE, PASSPORT_A);
        _anchorResponse(BOB, RESPONSE_A, PASSPORT_A);
        _anchorPassport(ALICE, PASSPORT_B);
        _anchorResponse(CAROL, RESPONSE_B, PASSPORT_B);

        bytes32 receiptId =
            contribution.recordRepeatTradeUsage(ALICE, RESPONSE_A, RESPONSE_B);
        TradeProofContribution.Receipt memory receipt = contribution.getReceipt(receiptId);
        _assertEq(receipt.points, 20, "repeat points");
        _assertEq(receipt.beneficiary, ALICE, "repeat actor");
    }

    function testPublicGoodsRequiresReviewAndEnforcesPointRange() public {
        vm.expectRevert(TradeProofContribution.PointsOutOfRange.selector);
        vm.prank(ALICE);
        contribution.submitPublicGoodsContribution(
            TradeProofContribution.ContributionKind.SecurityFindingOrFix,
            bytes32(uint256(777)),
            15001
        );

        vm.prank(ALICE);
        bytes32 receiptId = contribution.submitPublicGoodsContribution(
            TradeProofContribution.ContributionKind.SecurityFindingOrFix,
            bytes32(uint256(778)),
            12000
        );
        TradeProofContribution.Receipt memory submitted = contribution.getReceipt(receiptId);
        _assertEq(
            uint256(submitted.state),
            uint256(TradeProofContribution.ReceiptState.PendingReview),
            "pending review"
        );

        contribution.reviewPublicGoodsContribution(receiptId, true, 10000, DECISION_HASH);
        TradeProofContribution.Receipt memory reviewed = contribution.getReceipt(receiptId);
        _assertEq(reviewed.points, 10000, "approved points");
        vm.warp(reviewed.eligibleAt);
        contribution.finalizeReceipt(receiptId);
        _assertEq(contribution.verifiedPoints(0, ALICE), 10000, "public goods verified");
    }

    function testOnlyReviewerCanApprovePublicGoods() public {
        vm.prank(ALICE);
        bytes32 receiptId = contribution.submitPublicGoodsContribution(
            TradeProofContribution.ContributionKind.AcceptedStandardChange,
            bytes32(uint256(779)),
            1000
        );

        vm.expectRevert(
            abi.encodeWithSelector(TradeProofContribution.NotReviewer.selector, BOB)
        );
        vm.prank(BOB);
        contribution.reviewPublicGoodsContribution(receiptId, true, 1000, DECISION_HASH);
    }

    function testExcludedReceiptCanBeAppealedAndRestored() public {
        _anchorPassport(ALICE, PASSPORT_A);
        vm.prank(ALICE);
        bytes32 receiptId = contribution.recordUniquePassport(PASSPORT_A);

        contribution.excludeReceipt(receiptId, REASON_HASH);
        vm.prank(ALICE);
        contribution.appealReceipt(receiptId, APPEAL_HASH);
        contribution.resolveAppeal(receiptId, true, 5, DECISION_HASH);

        TradeProofContribution.Receipt memory restored = contribution.getReceipt(receiptId);
        _assertEq(
            uint256(restored.state),
            uint256(TradeProofContribution.ReceiptState.PendingDelay),
            "restored state"
        );
        vm.warp(restored.eligibleAt);
        contribution.finalizeReceipt(receiptId);
        _assertEq(contribution.verifiedPoints(0, ALICE), 5, "restored points");
    }

    function testRevocationSubtractsFinalizedPointsBeforeSeasonClose() public {
        _anchorPassport(ALICE, PASSPORT_A);
        vm.prank(ALICE);
        bytes32 receiptId = contribution.recordUniquePassport(PASSPORT_A);
        TradeProofContribution.Receipt memory receipt = contribution.getReceipt(receiptId);
        vm.warp(receipt.eligibleAt);
        contribution.finalizeReceipt(receiptId);
        _assertEq(contribution.verifiedPoints(0, ALICE), 5, "before revoke");

        contribution.revokeReceipt(receiptId, REASON_HASH);
        _assertEq(contribution.verifiedPoints(0, ALICE), 0, "after revoke");
        TradeProofContribution.Receipt memory revoked = contribution.getReceipt(receiptId);
        _assertEq(
            uint256(revoked.state),
            uint256(TradeProofContribution.ReceiptState.Revoked),
            "revoked state"
        );
    }

    function testWalletPairSeasonCapStopsWashLoop() public {
        _anchorPassport(ALICE, PASSPORT_A);
        for (uint256 index = 0; index < 10; index++) {
            bytes32 responseDigest = bytes32(uint256(1000 + index));
            _anchorResponse(BOB, responseDigest, PASSPORT_A);
            contribution.recordIndependentResponse(responseDigest);
        }

        bytes32 eleventhResponse = bytes32(uint256(1010));
        _anchorResponse(BOB, eleventhResponse, PASSPORT_A);
        vm.expectRevert(TradeProofContribution.PairSeasonCapExceeded.selector);
        contribution.recordIndependentResponse(eleventhResponse);
    }

    function testClosedSeasonFreezesFinalizedReceiptHistory() public {
        _anchorPassport(ALICE, PASSPORT_A);
        vm.prank(ALICE);
        bytes32 receiptId = contribution.recordUniquePassport(PASSPORT_A);
        TradeProofContribution.Receipt memory receipt = contribution.getReceipt(receiptId);
        vm.warp(receipt.eligibleAt);
        contribution.finalizeReceipt(receiptId);

        vm.warp(contribution.seasonClosableAt(0));
        contribution.closeSeason(0);
        _assertTrue(contribution.seasonClosed(0), "season closed");

        vm.expectRevert(abi.encodeWithSelector(TradeProofContribution.ClosedSeason.selector, 0));
        contribution.revokeReceipt(receiptId, REASON_HASH);
    }

    function _anchorPassport(address issuer, bytes32 digest) private {
        vm.prank(issuer);
        registry.anchorPassport(digest, SCHEMA_HASH, PROFILE_HASH, bytes32(0));
    }

    function _anchorResponse(address issuer, bytes32 digest, bytes32 passportDigest) private {
        vm.prank(issuer);
        registry.anchorResponse(digest, passportDigest, SCHEMA_HASH, PROFILE_HASH, bytes32(0));
    }

    function _declareRole(address responder, bytes32 responseDigest, bytes32 roleHash) private {
        vm.prank(responder);
        contribution.declareResponseRole(responseDigest, roleHash);
    }

    function _assertTrue(bool value, string memory message) private pure {
        require(value, message);
    }

    function _assertEq(address left, address right, string memory message) private pure {
        require(left == right, message);
    }

    function _assertEq(uint256 left, uint256 right, string memory message) private pure {
        require(left == right, message);
    }
}
