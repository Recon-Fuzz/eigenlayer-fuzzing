// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {EigenLayerSetupV2} from "./EigenLayerSetupV2.sol";
import {EigenLayerSystem} from "./EigenLayerSystem.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import "forge-std/Test.sol";

contract EigenLayerSystemTest is EigenLayerSystem {
    MockERC20 stETH;
    MockERC20 cbETH;

    address[] public tokenAddressArray = new address[](2);

    function test_deployEigenLayer_local() public {
        deployEigenLayerLocal();
    }

    function test_addStrategiesToDepositWhitelist() public {
        deployEigenLayerLocal();

        address[] memory deployedStrategies = new address[](1);
        bool[] memory thirdPartyTransfers = new bool[](1);
        _addStrategiesToDepositWhitelist(deployedStrategies, thirdPartyTransfers);
    }

    function test_slash_native() public {
        // setting up EigenPod to be slashable
        vm.deal(address(this), 32 ether);
        deployEigenLayerLocal();

        eigenPodManager.createPod();

        bytes memory pubkey = hex"123456";
        bytes memory signature = hex"789101";
        bytes32 dataRoot = bytes32(uint256(0xbeef));

        eigenPodManager.stake{value: 32 ether}(pubkey, signature, dataRoot);

        address podAddress = getPodForOwner(address(this));
        uint256 depositContractBalanceBefore = address(ethPOSDepositMock).balance;
        int256 podOwnerSharesBefore = eigenPodManager.podOwnerShares(address(this));

        // slash the created EigenPod
        vm.startPrank(podAddress);
        slashNative(address(this));
        vm.stopPrank();

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

    function test_slashing_ETHDeposit() public {
        deployEigenLayerLocal();

        bytes memory pubkey = hex"123456";
        bytes memory withdrawalCredentials = hex"789101";
        bytes memory signature = hex"789101";
        bytes32 dataRoot = bytes32(uint256(0xbeef));

        bytes memory data = abi.encodeWithSignature(
            "deposit(bytes,bytes,bytes,bytes32)",
            pubkey,
            withdrawalCredentials,
            signature,
            dataRoot
        );

        vm.deal(address(this), 32 ether);
        // send ETH directly to deposit contract
        (bool success, ) = address(ethPOSDepositMock).call{value: 32 ether}(data);
        require(success, "tansfering to deposit contract failed");

        console2.log("deposit balance before: ", address(ethPOSDepositMock).balance);
        ethPOSDepositMock.slash(1 ether);
        console2.log("deposit balance after: ", address(ethPOSDepositMock).balance);
    }

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
}
