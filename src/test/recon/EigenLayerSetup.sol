// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {vm} from "@chimera/Hevm.sol";

import "src/test/mocks/ETHDepositMock.sol";
import "src/contracts/core/Slasher.sol";
import "src/contracts/core/DelegationManager.sol";
import "src/contracts/core/StrategyManager.sol";
import "src/contracts/pods/EigenPod.sol";
import "src/contracts/pods/EigenPodManager.sol";
import "src/contracts/pods/DelayedWithdrawalRouter.sol";
import "src/test/mocks/ETHDepositMock.sol";
import "src/test/mocks/BeaconChainOracleMock.sol";
import "src/contracts/permissions/PauserRegistry.sol";
import "src/contracts/core/StrategyManager.sol";
import "src/contracts/strategies/StrategyBase.sol";
import "src/test/mocks/EmptyContract.sol";
import "src/contracts/strategies/StrategyBaseTVLLimits.sol";

import "forge-std/console2.sol";

// this contract deploys the EigenLayer system for use by an integrating system
// to use, the deployEigenLayer function is called by the setup function in the integrating system's fuzz suite
// which either inherits this contract to have access to the deployed contracts and their state variables
contract EigenLayerSetup {
    // EigenLayer system components:
    // 1. EigenPodManager (EigenPodManager, EigenPod, DelayedWithdrawalRouter, EigenLayerBeaconOracle)
    // 2. StrategyManager (StrategyManager, StrategyBaseTVLLimits)
    // 3. DelegationManager
    // 4. AVSDirectory
    // 5. Slasher (under development)

    // struct used to encode token info in config file
    struct StrategyConfig {
        uint256 maxDeposits;
        uint256 maxPerDeposit;
        address tokenAddress;
        string tokenSymbol;
    }

    // EigenLayer Contracts
    ProxyAdmin public eigenLayerProxyAdmin;
    PauserRegistry public eigenLayerPauserReg;
    Slasher public slasher;
    Slasher public slasherImplementation;
    DelegationManager public delegation;
    DelegationManager public delegationImplementation;
    StrategyManager public strategyManager;
    StrategyManager public strategyManagerImplementation;
    EigenPodManager public eigenPodManager;
    EigenPodManager public eigenPodManagerImplementation;
    DelayedWithdrawalRouter public delayedWithdrawalRouter;
    DelayedWithdrawalRouter public delayedWithdrawalRouterImplementation;
    UpgradeableBeacon public eigenPodBeacon;
    EigenPod public eigenPodImplementation;
    StrategyBase public baseStrategyImplementation;
    IStrategy[] public strategies;
    uint256[] public withdrawalDelayBlocks;

    EmptyContract public emptyContract;

    // BeaconChain deposit contract & beacon chain oracle
    ETHPOSDepositMock public ethPOSDepositMock; // mock for now, actual implementation requires forking
    address public beaconChainOracle;

    address admin = address(this);
    uint256 MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR = 32 gwei; // taken from mainnet deployment
    uint64 GENESIS_TIME = 1616508000; // taken from mainnet deployment
    // NOTE: setting these to false so that contracts can immediately be interacted with
    uint256 DELEGATION_INIT_PAUSED_STATUS = 0;
    uint256 DELEGATION_INIT_WITHDRAWAL_DELAY_BLOCKS = 0;
    uint256 STRATEGY_MANAGER_INIT_PAUSED_STATUS = 0;
    uint256 SLASHER_INIT_PAUSED_STATUS = 0;
    uint256 EIGENPOD_MANAGER_INIT_PAUSED_STATUS = 0;
    uint256 DELAYED_WITHDRAWAL_ROUTER_INIT_PAUSED_STATUS = 0;
    uint256 DELAYED_WITHDRAWAL_ROUTER_INIT_WITHDRAWAL_DELAY_BLOCKS = 0; // taken from mainnet deployment

    // this function will ultimately have local or fork option
    // NOTE: this copies the logic of the M1_Deploy script to deploy the entire system
    // eventually add the contracts in the M2 implementation
    function deployEigenLayer() public {
        // tokens to deploy strategies for
        StrategyConfig[] memory strategyConfigs; // these need to have some sort of mock implementation included

        // deploy proxy admin for ability to upgrade proxy contracts
        vm.prank(admin);
        eigenLayerProxyAdmin = new ProxyAdmin();

        //deploy pauser registry
        {
            address[] memory pausers = new address[](1);
            pausers[0] = admin;
            eigenLayerPauserReg = new PauserRegistry(pausers, admin);
        }

        /** 
            First the upgradeable proxy contracts that will point to implementation contracts get deployed.
            Since implementation contracts aren't yet deployed, they pass in an empty contract as a placeholder
        */
        emptyContract = new EmptyContract();
        delegation = DelegationManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );
        strategyManager = StrategyManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );
        slasher = Slasher(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );
        eigenPodManager = EigenPodManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );
        delayedWithdrawalRouter = DelayedWithdrawalRouter(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenLayerProxyAdmin), ""))
        );

        // deploy the ethPOS
        ethPOSDepositMock = new ETHPOSDepositMock();

        // deploy EigenPod
        eigenPodImplementation = new EigenPod(
            ethPOSDepositMock,
            delayedWithdrawalRouter,
            eigenPodManager,
            uint64(MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR),
            GENESIS_TIME
        );

        // this is used in EigenPodManager to set the implementation that supplies source bytecode every time a new pod is deployed
        eigenPodBeacon = new UpgradeableBeacon(address(eigenPodImplementation));

        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        delegationImplementation = new DelegationManager(strategyManager, slasher, eigenPodManager);
        strategyManagerImplementation = new StrategyManager(delegation, eigenPodManager, slasher);
        slasherImplementation = new Slasher(strategyManager, delegation);
        eigenPodManagerImplementation = new EigenPodManager(
            ethPOSDepositMock,
            eigenPodBeacon,
            strategyManager,
            slasher,
            delegation
        );

        delayedWithdrawalRouterImplementation = new DelayedWithdrawalRouter(eigenPodManager);

        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(delegation))),
            address(delegationImplementation),
            abi.encodeWithSelector(
                DelegationManager.initialize.selector,
                admin,
                eigenLayerPauserReg,
                DELEGATION_INIT_PAUSED_STATUS,
                DELEGATION_INIT_WITHDRAWAL_DELAY_BLOCKS,
                // NOTE: passing in empty arrays for these two for now while figuring out how to deploy strategies
                // TODO: change these once strategy deployments are handled
                strategies,
                withdrawalDelayBlocks
            )
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(strategyManager))),
            address(strategyManagerImplementation),
            abi.encodeWithSelector(
                StrategyManager.initialize.selector,
                admin,
                admin,
                eigenLayerPauserReg,
                STRATEGY_MANAGER_INIT_PAUSED_STATUS
            )
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(slasher))),
            address(slasherImplementation),
            abi.encodeWithSelector(Slasher.initialize.selector, admin, eigenLayerPauserReg, SLASHER_INIT_PAUSED_STATUS)
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(eigenPodManager))),
            address(eigenPodManagerImplementation),
            abi.encodeWithSelector(
                EigenPodManager.initialize.selector,
                // EIGENPOD_MANAGER_MAX_PODS, //this was deprecated to not be included in latest version of EigenPodManager
                // @audit this is setting the oracle address to 0 initially
                IBeaconChainOracle(address(0)),
                admin,
                eigenLayerPauserReg,
                EIGENPOD_MANAGER_INIT_PAUSED_STATUS
            )
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(delayedWithdrawalRouter))),
            address(delayedWithdrawalRouterImplementation),
            abi.encodeWithSelector(
                DelayedWithdrawalRouter.initialize.selector,
                admin,
                eigenLayerPauserReg,
                DELAYED_WITHDRAWAL_ROUTER_INIT_PAUSED_STATUS,
                DELAYED_WITHDRAWAL_ROUTER_INIT_WITHDRAWAL_DELAY_BLOCKS
            )
        );

        // deploy StrategyBaseTVLLimits contract implementation
        // baseStrategyImplementation = new StrategyBaseTVLLimits(strategyManager);

        // @audit logic for deploying strategies, handle this after all of the above have been tested
        // can use existing strategies deployed on mainnet
        // create upgradeable proxies that each point to the implementation and initialize them
        // for (uint256 i = 0; i < strategyConfigs.length; ++i) {
        //     deployedStrategyArray.push(
        //         StrategyBaseTVLLimits(
        //             address(
        //                 new TransparentUpgradeableProxy(
        //                     address(baseStrategyImplementation),
        //                     address(eigenLayerProxyAdmin),
        //                     abi.encodeWithSelector(
        //                         StrategyBaseTVLLimits.initialize.selector,
        //                         strategyConfigs[i].maxPerDeposit,
        //                         strategyConfigs[i].maxDeposits,
        //                         IERC20(strategyConfigs[i].tokenAddress),
        //                         eigenLayerPauserReg
        //                     )
        //                 )
        //             )
        //         )
        //     );
        // }
    }
}
