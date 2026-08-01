// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofRegistry } from "../contracts/TradeProofRegistry.sol";

interface Vm {
    function prank(address caller) external;
    function expectRevert(bytes calldata revertData) external;
}

contract TradeProofRegistryTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TradeProofRegistry private registry;

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);

    bytes32 private constant PASSPORT_V1 = bytes32(uint256(1));
    bytes32 private constant PASSPORT_V2 = bytes32(uint256(2));
    bytes32 private constant OTHER_PASSPORT = bytes32(uint256(3));
    bytes32 private constant RESPONSE_V1 = bytes32(uint256(11));
    bytes32 private constant RESPONSE_V2 = bytes32(uint256(12));
    bytes32 private constant SCHEMA_HASH = bytes32(uint256(101));
    bytes32 private constant PROFILE_HASH = bytes32(uint256(102));
    bytes32 private constant REASON_HASH = bytes32(uint256(103));

    function setUp() public {
        registry = new TradeProofRegistry();
    }

    function testAnchorPassportStoresIssuerProfileAndCurrentState() public {
        _anchorPassport(ALICE, PASSPORT_V1, bytes32(0));

        TradeProofRegistry.Anchor memory anchor = registry.getAnchor(PASSPORT_V1);
        _assertEq(anchor.issuer, ALICE, "issuer");
        _assertEq(uint256(anchor.kind), uint256(TradeProofRegistry.ArtifactKind.Passport), "kind");
        _assertEq(anchor.subjectDigest, bytes32(0), "passport subject");
        _assertEq(anchor.schemaHash, SCHEMA_HASH, "schema hash");
        _assertEq(anchor.digestProfileHash, PROFILE_HASH, "profile hash");
        _assertTrue(anchor.anchoredAt > 0, "anchored time");
        _assertTrue(registry.exists(PASSPORT_V1), "exists");
        _assertTrue(registry.isCurrent(PASSPORT_V1), "current");
    }

    function testRejectsZeroDigest() public {
        vm.expectRevert(abi.encodeWithSelector(TradeProofRegistry.ZeroDigest.selector));
        vm.prank(ALICE);
        registry.anchorPassport(bytes32(0), SCHEMA_HASH, PROFILE_HASH, bytes32(0));
    }

    function testRejectsZeroSchemaHash() public {
        vm.expectRevert(abi.encodeWithSelector(TradeProofRegistry.ZeroSchemaHash.selector));
        vm.prank(ALICE);
        registry.anchorPassport(PASSPORT_V1, bytes32(0), PROFILE_HASH, bytes32(0));
    }

    function testRejectsZeroDigestProfileHash() public {
        vm.expectRevert(abi.encodeWithSelector(TradeProofRegistry.ZeroDigestProfileHash.selector));
        vm.prank(ALICE);
        registry.anchorPassport(PASSPORT_V1, SCHEMA_HASH, bytes32(0), bytes32(0));
    }

    function testRejectsDuplicateDigest() public {
        _anchorPassport(ALICE, PASSPORT_V1, bytes32(0));

        vm.expectRevert(
            abi.encodeWithSelector(TradeProofRegistry.AlreadyAnchored.selector, PASSPORT_V1)
        );
        vm.prank(BOB);
        registry.anchorPassport(PASSPORT_V1, SCHEMA_HASH, PROFILE_HASH, bytes32(0));
    }

    function testResponseRequiresCurrentPassport() public {
        vm.expectRevert(
            abi.encodeWithSelector(TradeProofRegistry.CurrentPassportRequired.selector, PASSPORT_V1)
        );
        vm.prank(BOB);
        registry.anchorResponse(RESPONSE_V1, PASSPORT_V1, SCHEMA_HASH, PROFILE_HASH, bytes32(0));
    }

    function testResponseLinksToPassportWithoutChangingPassportIssuer() public {
        _anchorPassport(ALICE, PASSPORT_V1, bytes32(0));

        vm.prank(BOB);
        registry.anchorResponse(RESPONSE_V1, PASSPORT_V1, SCHEMA_HASH, PROFILE_HASH, bytes32(0));

        TradeProofRegistry.Anchor memory response = registry.getAnchor(RESPONSE_V1);
        _assertEq(response.issuer, BOB, "response issuer");
        _assertEq(response.subjectDigest, PASSPORT_V1, "response subject");
        _assertEq(uint256(response.kind), uint256(TradeProofRegistry.ArtifactKind.Response), "kind");
        _assertTrue(registry.isCurrent(PASSPORT_V1), "passport remains current");
        _assertTrue(registry.isCurrent(RESPONSE_V1), "response current");
    }

    function testOnlyIssuerCanRevoke() public {
        _anchorPassport(ALICE, PASSPORT_V1, bytes32(0));

        vm.expectRevert(
            abi.encodeWithSelector(TradeProofRegistry.NotIssuer.selector, PASSPORT_V1, BOB)
        );
        vm.prank(BOB);
        registry.revoke(PASSPORT_V1, REASON_HASH);
    }

    function testRevokeMakesArtifactNotCurrentAndPreservesHistory() public {
        _anchorPassport(ALICE, PASSPORT_V1, bytes32(0));

        vm.prank(ALICE);
        registry.revoke(PASSPORT_V1, REASON_HASH);

        TradeProofRegistry.Anchor memory anchor = registry.getAnchor(PASSPORT_V1);
        _assertTrue(anchor.revokedAt > 0, "revoked time");
        _assertEq(anchor.revocationReasonHash, REASON_HASH, "reason hash");
        _assertTrue(registry.exists(PASSPORT_V1), "history exists");
        _assertFalse(registry.isCurrent(PASSPORT_V1), "not current");
    }

    function testSupersessionLinksBothVersionsAndMovesCurrentState() public {
        _anchorPassport(ALICE, PASSPORT_V1, bytes32(0));
        _anchorPassport(ALICE, PASSPORT_V2, PASSPORT_V1);

        TradeProofRegistry.Anchor memory first = registry.getAnchor(PASSPORT_V1);
        TradeProofRegistry.Anchor memory second = registry.getAnchor(PASSPORT_V2);
        _assertEq(first.successorDigest, PASSPORT_V2, "successor");
        _assertEq(second.supersedesDigest, PASSPORT_V1, "predecessor");
        _assertFalse(registry.isCurrent(PASSPORT_V1), "old not current");
        _assertTrue(registry.isCurrent(PASSPORT_V2), "new current");
    }

    function testCannotSupersedeAnotherIssuersArtifact() public {
        _anchorPassport(ALICE, PASSPORT_V1, bytes32(0));

        vm.expectRevert(
            abi.encodeWithSelector(TradeProofRegistry.NotIssuer.selector, PASSPORT_V1, BOB)
        );
        vm.prank(BOB);
        registry.anchorPassport(PASSPORT_V2, SCHEMA_HASH, PROFILE_HASH, PASSPORT_V1);
    }

    function testCannotSupersedeDifferentArtifactKind() public {
        _anchorPassport(ALICE, PASSPORT_V1, bytes32(0));

        vm.prank(ALICE);
        registry.anchorResponse(RESPONSE_V1, PASSPORT_V1, SCHEMA_HASH, PROFILE_HASH, bytes32(0));

        vm.expectRevert(
            abi.encodeWithSelector(TradeProofRegistry.KindMismatch.selector, RESPONSE_V1)
        );
        vm.prank(ALICE);
        registry.anchorPassport(PASSPORT_V2, SCHEMA_HASH, PROFILE_HASH, RESPONSE_V1);
    }

    function testResponseSupersessionMustKeepSamePassportSubject() public {
        _anchorPassport(ALICE, PASSPORT_V1, bytes32(0));
        _anchorPassport(ALICE, OTHER_PASSPORT, bytes32(0));

        vm.prank(BOB);
        registry.anchorResponse(RESPONSE_V1, PASSPORT_V1, SCHEMA_HASH, PROFILE_HASH, bytes32(0));

        vm.expectRevert(
            abi.encodeWithSelector(TradeProofRegistry.SubjectMismatch.selector, RESPONSE_V1)
        );
        vm.prank(BOB);
        registry.anchorResponse(RESPONSE_V2, OTHER_PASSPORT, SCHEMA_HASH, PROFILE_HASH, RESPONSE_V1);
    }

    function _anchorPassport(address issuer, bytes32 digest, bytes32 supersedesDigest) private {
        vm.prank(issuer);
        registry.anchorPassport(digest, SCHEMA_HASH, PROFILE_HASH, supersedesDigest);
    }

    function _assertTrue(bool value, string memory message) private pure {
        require(value, message);
    }

    function _assertFalse(bool value, string memory message) private pure {
        require(!value, message);
    }

    function _assertEq(address left, address right, string memory message) private pure {
        require(left == right, message);
    }

    function _assertEq(bytes32 left, bytes32 right, string memory message) private pure {
        require(left == right, message);
    }

    function _assertEq(uint256 left, uint256 right, string memory message) private pure {
        require(left == right, message);
    }
}
