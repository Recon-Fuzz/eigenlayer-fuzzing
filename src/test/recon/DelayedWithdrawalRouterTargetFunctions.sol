// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {Properties} from "./Properties.sol";
import {vm} from "@chimera/Hevm.sol";

abstract contract DelayedWithdrawalRouterTargetFunctions is BaseTargetFunctions, Properties, BeforeAfter {
    function delayedWithdrawalRouter_claimDelayedWithdrawals(uint256 maxNumberOfDelayedWithdrawalsToClaim) public {
        delayedWithdrawalRouter.claimDelayedWithdrawals(maxNumberOfDelayedWithdrawalsToClaim);
    }

    function delayedWithdrawalRouter_claimDelayedWithdrawals(
        address recipient,
        uint256 maxNumberOfDelayedWithdrawalsToClaim
    ) public {
        delayedWithdrawalRouter.claimDelayedWithdrawals(recipient, maxNumberOfDelayedWithdrawalsToClaim);
    }

    function delayedWithdrawalRouter_createDelayedWithdrawal(address podOwner, address recipient) public {
        delayedWithdrawalRouter.createDelayedWithdrawal(podOwner, recipient);
    }

    function delayedWithdrawalRouter_initialize(
        address initOwner,
        address _pauserRegistry,
        uint256 initPausedStatus,
        uint256 _withdrawalDelayBlocks
    ) public {
        delayedWithdrawalRouter.initialize(
            initOwner,
            IPauserRegistry(_pauserRegistry),
            initPausedStatus,
            _withdrawalDelayBlocks
        );
    }

    function delayedWithdrawalRouter_pause(uint256 newPausedStatus) public {
        delayedWithdrawalRouter.pause(newPausedStatus);
    }

    function delayedWithdrawalRouter_pauseAll() public {
        delayedWithdrawalRouter.pauseAll();
    }

    function delayedWithdrawalRouter_renounceOwnership() public {
        delayedWithdrawalRouter.renounceOwnership();
    }

    function delayedWithdrawalRouter_setPauserRegistry(address newPauserRegistry) public {
        delayedWithdrawalRouter.setPauserRegistry(IPauserRegistry(newPauserRegistry));
    }

    function delayedWithdrawalRouter_setWithdrawalDelayBlocks(uint256 newValue) public {
        delayedWithdrawalRouter.setWithdrawalDelayBlocks(newValue);
    }

    function delayedWithdrawalRouter_transferOwnership(address newOwner) public {
        delayedWithdrawalRouter.transferOwnership(newOwner);
    }

    function delayedWithdrawalRouter_unpause(uint256 newPausedStatus) public {
        delayedWithdrawalRouter.unpause(newPausedStatus);
    }
}
