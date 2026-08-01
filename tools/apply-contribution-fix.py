from pathlib import Path

contract_path = Path("contracts/TradeProofContribution.sol")
contract_source = contract_path.read_text(encoding="utf-8")

if "function _validateThirdDistinctResponderRoles(" not in contract_source:
    start_marker = "    function recordThirdDistinctResponderRole("
    end_marker = "    /// @notice Record the 50/25 viral-reuse reward"
    helper_marker = "    function _consumePairPoints("

    start = contract_source.find(start_marker)
    end = contract_source.find(end_marker, start)
    helper_at = contract_source.find(helper_marker)
    if start < 0 or end < 0 or helper_at < 0:
        raise SystemExit("Expected contribution source markers were not found")

    replacement = '''    function recordThirdDistinctResponderRole(
        bytes32 passportDigest,
        bytes32 responseDigestA,
        bytes32 responseDigestB,
        bytes32 responseDigestC
    ) external returns (bytes32 receiptId) {
        address passportIssuer = _validateThirdDistinctResponderRoles(
            passportDigest, responseDigestA, responseDigestB, responseDigestC
        );
        (bytes32 first, bytes32 second, bytes32 third) =
            _sortThree(responseDigestA, responseDigestB, responseDigestC);
        bytes32 responseSetDigest = keccak256(abi.encode(first, second, third));
        bytes32 eventKey = keccak256(
            abi.encode(
                ContributionKind.ThirdDistinctResponderRole,
                passportDigest,
                responseSetDigest
            )
        );
        receiptId = _recordAutomatic(
            eventKey,
            passportIssuer,
            ContributionKind.ThirdDistinctResponderRole,
            30,
            passportDigest,
            responseSetDigest
        );
    }

'''

    contract_source = contract_source[:start] + replacement + contract_source[end:]
    helper_at = contract_source.find(helper_marker)
    helper = '''    function _validateThirdDistinctResponderRoles(
        bytes32 passportDigest,
        bytes32 responseDigestA,
        bytes32 responseDigestB,
        bytes32 responseDigestC
    ) private view returns (address passportIssuer) {
        passportIssuer = _currentPassport(passportDigest).issuer;
        (address responderA, bytes32 roleA) =
            _responderAndRole(responseDigestA, passportDigest, passportIssuer);
        (address responderB, bytes32 roleB) =
            _responderAndRole(responseDigestB, passportDigest, passportIssuer);
        (address responderC, bytes32 roleC) =
            _responderAndRole(responseDigestC, passportDigest, passportIssuer);

        if (responderA == responderB) revert DuplicateParticipant(responderA);
        if (responderA == responderC) revert DuplicateParticipant(responderA);
        if (responderB == responderC) revert DuplicateParticipant(responderB);
        if (roleA == roleB) revert DuplicateRole(roleA);
        if (roleA == roleC) revert DuplicateRole(roleA);
        if (roleB == roleC) revert DuplicateRole(roleB);
    }

    function _responderAndRole(
        bytes32 responseDigest,
        bytes32 passportDigest,
        address passportIssuer
    ) private view returns (address responder, bytes32 roleHash) {
        responder = _responseForPassport(responseDigest, passportDigest).issuer;
        if (responder == passportIssuer) revert SelfResponseNotEligible(responseDigest);
        roleHash = responseRoleHash[responseDigest];
        if (roleHash == bytes32(0)) revert RoleNotDeclared(responseDigest);
    }

'''
    contract_source = contract_source[:helper_at] + helper + contract_source[helper_at:]
    contract_path.write_text(contract_source, encoding="utf-8")

test_path = Path("test/TradeProofContribution.t.sol")
test_source = test_path.read_text(encoding="utf-8")

replacements = {
    "vm.expectRevert(TradeProofContribution.ReviewDelayActive.selector);": '''vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.ReviewDelayActive.selector, receiptId, receipt.eligibleAt
            )
        );''',
    "vm.expectRevert(TradeProofContribution.DuplicateRole.selector);": '''vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.DuplicateRole.selector, bytes32("buyer")
            )
        );''',
    "vm.expectRevert(TradeProofContribution.ViralReuseWindowMissed.selector);": '''vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.ViralReuseWindowMissed.selector,
                RESPONSE_A,
                PASSPORT_B
            )
        );''',
    "vm.expectRevert(TradeProofContribution.PointsOutOfRange.selector);": '''vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.PointsOutOfRange.selector, 15001, 500, 15000
            )
        );''',
    '''        vm.expectRevert(TradeProofContribution.PairSeasonCapExceeded.selector);
        contribution.recordIndependentResponse(eleventhResponse);''': '''        bytes32 pairKey = keccak256(abi.encode(ALICE, BOB));
        vm.expectRevert(
            abi.encodeWithSelector(
                TradeProofContribution.PairSeasonCapExceeded.selector, pairKey, 330
            )
        );
        contribution.recordIndependentResponse(eleventhResponse);''',
}

for old, new in replacements.items():
    if old in test_source:
        test_source = test_source.replace(old, new, 1)

test_path.write_text(test_source, encoding="utf-8")
