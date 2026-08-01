from pathlib import Path

path = Path("contracts/TradeProofContribution.sol")
source = path.read_text(encoding="utf-8")

if "function _validateThirdDistinctResponderRoles(" in source:
    raise SystemExit(0)

start_marker = "    function recordThirdDistinctResponderRole("
end_marker = "    /// @notice Record the 50/25 viral-reuse reward"
helper_marker = "    function _consumePairPoints("

start = source.find(start_marker)
end = source.find(end_marker, start)
helper_at = source.find(helper_marker)
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

source = source[:start] + replacement + source[end:]
helper_at = source.find(helper_marker)
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
source = source[:helper_at] + helper + source[helper_at:]
path.write_text(source, encoding="utf-8")
