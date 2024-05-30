// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {EigenLayerSetupV2} from "src/test/recon/EigenLayerSetupV2.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import "forge-std/Test.sol";

contract EigenLayerSetupTest is EigenLayerSetupV2, Test {
    MockERC20 stETH;
    MockERC20 cbETH;

    address[] public tokenAddressArray = new address[](2);

    function test_deployEigenLayer() public {
        // stETH = new MockERC20("Staked ETH", "stETH", 18);
        // cbETH = new MockERC20("Coinbase ETH", "cbETH", 18);

        // tokenAddressArray[0] = address(stETH);
        // tokenAddressArray[1] = address(cbETH);

        deployEigenLayerLocal();
    }

    function test_addStrategiesToDepositWhitelist() public {
        deployEigenLayerLocal();

        address[] memory deployedStrategies = new address[](1);
        bool[] memory thirdPartyTransfers = new bool[](1);
        _addStrategiesToDepositWhitelist(deployedStrategies, thirdPartyTransfers);
    }

    function test_slashing() public {
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
        ethPOSDepositMock.slash();
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
