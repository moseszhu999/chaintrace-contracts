// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofRegistry } from "../contracts/TradeProofRegistry.sol";

interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// @notice Foundry deployment script for local networks or Base Sepolia.
/// @dev The signer is supplied by the Foundry CLI, for example:
/// forge script script/DeployTradeProofRegistry.s.sol:DeployTradeProofRegistry \
///   --rpc-url base_sepolia --private-key "$DEPLOYER_PRIVATE_KEY" --broadcast
contract DeployTradeProofRegistry {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (TradeProofRegistry registry) {
        vm.startBroadcast();
        registry = new TradeProofRegistry();
        vm.stopBroadcast();
    }
}
