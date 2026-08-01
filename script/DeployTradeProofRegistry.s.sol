// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TradeProofRegistry } from "../contracts/TradeProofRegistry.sol";

interface Vm {
    function envUint(string calldata name) external returns (uint256 value);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

/// @notice Foundry deployment script for local networks or Base Sepolia.
/// @dev Example:
/// forge script script/DeployTradeProofRegistry.s.sol:DeployTradeProofRegistry \
///   --rpc-url base_sepolia --broadcast
contract DeployTradeProofRegistry {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (TradeProofRegistry registry) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        registry = new TradeProofRegistry();
        vm.stopBroadcast();
    }
}
