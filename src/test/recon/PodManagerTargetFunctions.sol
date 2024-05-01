// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {Properties} from "./Properties.sol";
import {vm} from "@chimera/Hevm.sol";

abstract contract PodManagerTargetFunctions is BaseTargetFunctions, Properties, BeforeAfter {
    function eigenPodManager_addShares(address podOwner, uint256 shares) public {
        eigenPodManager.addShares(podOwner, shares);
    }

    function eigenPodManager_createPod() public {
        eigenPodManager.createPod();
    }

    function eigenPodManager_initialize(
        uint256 _maxPods,
        address _beaconChainOracle,
        address initialOwner,
        address _pauserRegistry,
        uint256 _initPausedStatus
    ) public {
        eigenPodManager.initialize(
            _maxPods,
            IBeaconChainOracle(_beaconChainOracle),
            initialOwner,
            IPauserRegistry(_pauserRegistry),
            _initPausedStatus
        );
    }

    function eigenPodManager_recordBeaconChainETHBalanceUpdate(address podOwner, int256 sharesDelta) public {
        eigenPodManager.recordBeaconChainETHBalanceUpdate(podOwner, sharesDelta);
    }

    function eigenPodManager_removeShares(address podOwner, uint256 shares) public {
        eigenPodManager.removeShares(podOwner, shares);
    }

    function eigenPodManager_stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) public {
        eigenPodManager.stake(pubkey, signature, depositDataRoot);
    }

    function eigenPodManager_withdrawSharesAsTokens(address podOwner, address destination, uint256 shares) public {
        eigenPodManager.withdrawSharesAsTokens(podOwner, destination, shares);
    }
}
