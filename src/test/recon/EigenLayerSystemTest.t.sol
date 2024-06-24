// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EigenLayerSetupV2} from "./EigenLayerSetupV2.sol";
import {EigenLayerSystem} from "./EigenLayerSystem.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IStrategy} from "../../../src/contracts/interfaces/IStrategy.sol";
import "forge-std/Test.sol";

contract EigenLayerSystemTest is EigenLayerSystem {
    using SafeERC20 for IERC20;

    MockERC20 stETH;
    MockERC20 wbETH;

    address[] public tokenAddressArray = new address[](2);

    function test_deployEigenLayer_local() public {
        stETH = new MockERC20("lido staked ETH", "stETH", 18);
        wbETH = new MockERC20("binance staked ETH", "wbETH", 18);
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(stETH);
        tokenAddresses[1] = address(wbETH);

        deployEigenLayerLocal(tokenAddresses);
    }

    // function test_addStrategiesToDepositWhitelist() public {
    //     deployEigenLayerLocal();

    //     address[] memory deployedStrategies = new address[](1);
    //     bool[] memory thirdPartyTransfers = new bool[](1);
    //     _addStrategiesToDepositWhitelist(deployedStrategies, thirdPartyTransfers);
    // }

    function test_slash_native() public {
        // setting up EigenPod to be slashable
        vm.deal(address(this), 32 ether);
        _deployTokensAndEigenLayerSystem();

        eigenPodManager.createPod();

        bytes memory pubkey = hex"123456";
        bytes memory signature = hex"789101";
        bytes32 dataRoot = bytes32(uint256(0xbeef));

        eigenPodManager.stake{value: 32 ether}(pubkey, signature, dataRoot);

        uint256 depositContractBalanceBefore = address(ethPOSDepositMock).balance;
        int256 podOwnerSharesBefore = eigenPodManager.podOwnerShares(address(this));

        // slash the created EigenPod
        slashNative(address(this));

        uint256 depositContractBalanceAfter = address(ethPOSDepositMock).balance;
        int256 podOwnerSharesAfter = eigenPodManager.podOwnerShares(address(this));

        console.log("balance before: ", depositContractBalanceBefore);
        console.log("balance after: ", depositContractBalanceAfter);
        assertTrue(
            depositContractBalanceBefore > depositContractBalanceAfter,
            "deposit contract balance doesn't decrease"
        );
        assertTrue(podOwnerSharesBefore > podOwnerSharesAfter, "pod owner shares don't decrease");
    }

    function test_slash_avs() public {
        _deployTokensAndEigenLayerSystem();

        vm.deal(address(this), 32 ether);
        stETH.mint(address(this), 32 ether);
        stETH.approve(address(strategyManager), type(uint256).max);

        // deposit into strategy
        IStrategy strategyToDeposit = IStrategy(address(deployedStrategyArray[0]));
        strategyManager.depositIntoStrategy(strategyToDeposit, IERC20(address(stETH)), 12 ether);

        // deposit into EigenPod
        eigenPodManager.createPod();
        bytes memory pubkey = hex"123456";
        bytes memory signature = hex"789101";
        bytes32 dataRoot = bytes32(uint256(0xbeef));
        eigenPodManager.stake{value: 32 ether}(pubkey, signature, dataRoot);

        uint256 depositContractBalanceBefore = address(ethPOSDepositMock).balance;
        int256 podOwnerSharesBefore = eigenPodManager.podOwnerShares(address(this));
        (, uint256[] memory LSTsharesBefore) = strategyManager.getDeposits(address(this));

        address[] memory strategies = new address[](1);
        strategies[0] = address(strategyToDeposit);

        // slash the user's deposited balance across native and LSTs
        slashAVS(address(this), strategies, 5 ether, 5 ether);

        uint256 depositContractBalanceAfter = address(ethPOSDepositMock).balance;
        int256 podOwnerSharesAfter = eigenPodManager.podOwnerShares(address(this));
        (, uint256[] memory LSTsharesafter) = strategyManager.getDeposits(address(this));

        // console.log("balance before: %e", podOwnerSharesBefore);
        // console.log("balance after: %e", podOwnerSharesAfter);
        assertTrue(
            depositContractBalanceBefore > depositContractBalanceAfter,
            "deposit contract balance doesn't decrease"
        );
        assertTrue(podOwnerSharesBefore > podOwnerSharesAfter, "pod owner shares don't decrease");
        assertTrue(LSTsharesBefore[0] > LSTsharesafter[0], "LST shares don't decrease");
    }

    /// @notice currently not functional
    // function test_deployEigenLayerFork() public {
    //     address[] memory strategyArray = new address[](2);
    //     address cbETHStrategyAddress = address(0x54945180dB7943c0ed0FEE7EdaB2Bd24620256bc);
    //     address stETHStrategyAddress = address(0x93c4b944D05dfe6df7645A86cd2206016c51564D);

    //     strategyArray[0] = cbETHStrategyAddress;
    //     strategyArray[1] = stETHStrategyAddress;

    //     // pass in addresses of the strategies used in Renzo here for accurate forking
    //     // need to include rpc url and block to fork from
    //     deployEigenLayerForked(strategyArray);
    // }

    function _deployTokensAndEigenLayerSystem() internal {
        stETH = new MockERC20("lido staked ETH", "stETH", 18);
        wbETH = new MockERC20("binance staked ETH", "wbETH", 18);
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(stETH);
        tokenAddresses[1] = address(wbETH);

        deployEigenLayerLocal(tokenAddresses);
    }
}
