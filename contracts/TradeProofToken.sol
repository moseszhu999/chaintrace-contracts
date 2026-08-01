// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title TradeProof Token
/// @notice Fixed-supply ERC-20 for the future TradeProof community economy.
/// @dev All supply is created once in the constructor. There is no owner or post-genesis mint path.
contract TradeProofToken {
    string public constant name = "TradeProof Token";
    string public constant symbol = "TPROOF";
    uint8 public constant decimals = 18;

    uint256 public constant TOKEN_UNIT = 1e18;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * TOKEN_UNIT;
    uint256 public constant COMMUNITY_ALLOCATION = 450_000_000 * TOKEN_UNIT;
    uint256 public constant ECOSYSTEM_ALLOCATION = 200_000_000 * TOKEN_UNIT;
    uint256 public constant TEAM_ALLOCATION = 150_000_000 * TOKEN_UNIT;
    uint256 public constant ADOPTION_ALLOCATION = 100_000_000 * TOKEN_UNIT;
    uint256 public constant LIQUIDITY_RESERVE_ALLOCATION = 50_000_000 * TOKEN_UNIT;
    uint256 public constant SECURITY_RESERVE_ALLOCATION = 50_000_000 * TOKEN_UNIT;

    uint256 public totalSupply;
    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    error ZeroAddress();
    error DuplicateRecipient(address recipient);
    error InsufficientBalance(address account, uint256 available, uint256 required);
    error InsufficientAllowance(address owner, address spender, uint256 available, uint256 required);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event GenesisAllocation(address indexed recipient, bytes32 indexed allocationId, uint256 amount);

    constructor(
        address communityTreasury,
        address ecosystemTreasury,
        address teamVestingEscrow,
        address adoptionTreasury,
        address liquidityReserve,
        address securityReserve
    ) {
        address[6] memory recipients = [
            communityTreasury,
            ecosystemTreasury,
            teamVestingEscrow,
            adoptionTreasury,
            liquidityReserve,
            securityReserve
        ];
        _validateRecipients(recipients);

        _genesisMint(communityTreasury, keccak256("COMMUNITY"), COMMUNITY_ALLOCATION);
        _genesisMint(ecosystemTreasury, keccak256("ECOSYSTEM"), ECOSYSTEM_ALLOCATION);
        _genesisMint(teamVestingEscrow, keccak256("TEAM_VESTING"), TEAM_ALLOCATION);
        _genesisMint(adoptionTreasury, keccak256("ADOPTION"), ADOPTION_ALLOCATION);
        _genesisMint(
            liquidityReserve, keccak256("LIQUIDITY_RESERVE"), LIQUIDITY_RESERVE_ALLOCATION
        );
        _genesisMint(
            securityReserve, keccak256("SECURITY_RESERVE"), SECURITY_RESERVE_ALLOCATION
        );

        assert(totalSupply == MAX_SUPPLY);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 approved = allowance[from][msg.sender];
        if (approved != type(uint256).max) {
            if (approved < amount) {
                revert InsufficientAllowance(from, msg.sender, approved, amount);
            }
            unchecked {
                allowance[from][msg.sender] = approved - amount;
            }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, amount);
        return true;
    }

    function _genesisMint(address recipient, bytes32 allocationId, uint256 amount) private {
        totalSupply += amount;
        balanceOf[recipient] += amount;
        emit Transfer(address(0), recipient, amount);
        emit GenesisAllocation(recipient, allocationId, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        if (to == address(0)) revert ZeroAddress();
        uint256 available = balanceOf[from];
        if (available < amount) revert InsufficientBalance(from, available, amount);
        unchecked {
            balanceOf[from] = available - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _validateRecipients(address[6] memory recipients) private pure {
        for (uint256 index = 0; index < recipients.length; index++) {
            address recipient = recipients[index];
            if (recipient == address(0)) revert ZeroAddress();
            for (uint256 prior = 0; prior < index; prior++) {
                if (recipient == recipients[prior]) revert DuplicateRecipient(recipient);
            }
        }
    }
}
