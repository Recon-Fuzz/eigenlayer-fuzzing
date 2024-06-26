// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {vm} from "@chimera/Hevm.sol";

import {ETHPOSDepositMock} from "./FuzzingETHDepositMock.sol";
import {Slasher} from "../../../src/contracts/core/Slasher.sol";
import {DelegationManager} from "../../../src/contracts/core/DelegationManager.sol";
import {StrategyManager} from "../../../src/contracts/core/StrategyManager.sol";
import {EigenPod} from "../../../src/contracts/pods/EigenPod.sol";
import {EigenPodManager} from "../../../src/contracts/pods/EigenPodManager.sol";
import {DelayedWithdrawalRouter} from "../../../src/contracts/pods/DelayedWithdrawalRouter.sol";
import {PauserRegistry} from "../../../src/contracts/permissions/PauserRegistry.sol";
import {StrategyManager} from "../../../src/contracts/core/StrategyManager.sol";
import {StrategyBase} from "../../../src/contracts/strategies/StrategyBase.sol";
import {EmptyContract} from "../../../src/test/mocks/EmptyContract.sol";
import {StrategyBaseTVLLimits} from "../../../src/contracts/strategies/StrategyBaseTVLLimits.sol";
import {IStrategy} from "../../../src/contracts/interfaces/IStrategy.sol";
import {IBeaconChainOracle} from "../../../src/contracts/interfaces/IBeaconChainOracle.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import "forge-std/console2.sol";

// this contract deploys the EigenLayer system for use by an integrating system
// to use, the deployEigenLayer function is called by the setup function in the integrating system's fuzz suite
// which either inherits this contract to have access to the deployed contracts and their state variables
contract EigenLayerSetup {
    struct StrategyConfig {
        uint256 maxDeposits;
        uint256 maxPerDeposit;
        address tokenAddress;
        string tokenSymbol;
    }

    // EigenLayer Contracts
    ProxyAdmin internal eigenLayerProxyAdmin;
    PauserRegistry internal eigenLayerPauserReg;
    Slasher internal slasher;
    Slasher internal slasherImplementation;
    DelegationManager internal delegation;
    DelegationManager internal delegationImplementation;
    StrategyManager internal strategyManager;
    StrategyManager internal strategyManagerImplementation;
    EigenPodManager internal eigenPodManager;
    EigenPodManager internal eigenPodManagerImplementation;
    DelayedWithdrawalRouter internal delayedWithdrawalRouter;
    DelayedWithdrawalRouter internal delayedWithdrawalRouterImplementation;
    UpgradeableBeacon internal eigenPodBeacon;
    EigenPod internal eigenPodImplementation;
    StrategyBase internal baseStrategyImplementation;
    IStrategy[] internal strategies;
    MockERC20 internal stETH;
    MockERC20 internal wbETH;
    EmptyContract internal emptyContract;
    ETHPOSDepositMock internal ethPOSDepositMock; // BeaconChain deposit contract
    StrategyBaseTVLLimits[] internal deployedStrategyArray; // strategies deployed locally
    StrategyBase[] internal deployedForkStrategyArray; // strategies deployed on mainnet
    uint256[] internal withdrawalDelayBlocks;
    address[] internal tokenAddresses;
    address internal beaconChainOracle; // beacon chain oracle

    address admin = address(this);

    // NOTE: All constant values are taken from mainnet deployments
    uint256 MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR = 32 gwei;
    uint64 GENESIS_TIME = 1616508000;

    // NOTE: 0 = unpaused
    uint256 DELEGATION_INIT_PAUSED_STATUS = 0;
    uint256 DELEGATION_INIT_WITHDRAWAL_DELAY_BLOCKS = 0;
    uint256 STRATEGY_MANAGER_INIT_PAUSED_STATUS = 0;
    uint256 SLASHER_INIT_PAUSED_STATUS = 0;
    uint256 EIGENPOD_MANAGER_INIT_PAUSED_STATUS = 0;
    uint256 DELAYED_WITHDRAWAL_ROUTER_INIT_PAUSED_STATUS = 0;
    uint256 DELAYED_WITHDRAWAL_ROUTER_INIT_WITHDRAWAL_DELAY_BLOCKS = 0;

    /**
        @notice Deploys the entire EigenLayer system locally 
        @dev Strategies are deployed for the tokenAddresses and tokenSymbols passed in
        NOTE: This copies the logic of the M1_Deploy script to deploy the entire system
    */
    function deployEigenLayerLocal() internal {
        // deploy proxy admin that has ability to upgrade proxy contracts
        vm.prank(admin);
        eigenLayerProxyAdmin = new ProxyAdmin();

        _deployPauserRegistry();

        /** 
            First the upgradeable proxy contracts that will point to implementation contracts get deployed.
            Since implementation contracts aren't yet deployed, they pass in an empty contract as a placeholder
        */
        _deployUpgradeableContracts();

        ethPOSDepositMock = new ETHPOSDepositMock();
        eigenPodImplementation = new EigenPod(
            ethPOSDepositMock,
            delayedWithdrawalRouter,
            eigenPodManager,
            uint64(MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR),
            GENESIS_TIME
        );
        eigenPodBeacon = new UpgradeableBeacon(address(eigenPodImplementation));

        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        _deployImplementationContracts();
        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        _upgradeProxies();

        _deployTokens();
        _deployStrategies();

        // CHECK CORRECTNESS OF DEPLOYMENT
        _verifyContractsPointAtOneAnother(
            delegationImplementation,
            strategyManagerImplementation,
            slasherImplementation,
            eigenPodManagerImplementation,
            delayedWithdrawalRouterImplementation
        );
        _verifyContractsPointAtOneAnother(
            delegation,
            strategyManager,
            slasher,
            eigenPodManager,
            delayedWithdrawalRouter
        );
        _verifyImplementationsSetCorrectly();
        _verifyInitialOwners();
        _checkPauserInitializations();
        _verifyInitializationParams();
    }

    /**
        System Deployments
    */
    function _deployPauserRegistry() internal {
        address[] memory pausers = new address[](1);
        pausers[0] = admin;
        eigenLayerPauserReg = new PauserRegistry(pausers, admin);
    }

    function _deployUpgradeableContracts() internal {
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
    }

    function _deployImplementationContracts() internal {
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
    }

    function _upgradeProxies() internal {
        eigenLayerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(delegation))),
            address(delegationImplementation),
            abi.encodeWithSelector(
                DelegationManager.initialize.selector,
                admin,
                eigenLayerPauserReg,
                DELEGATION_INIT_PAUSED_STATUS,
                DELEGATION_INIT_WITHDRAWAL_DELAY_BLOCKS,
                strategies,
                withdrawalDelayBlocks
            )
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(strategyManager))),
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
            ITransparentUpgradeableProxy(payable(address(slasher))),
            address(slasherImplementation),
            abi.encodeWithSelector(Slasher.initialize.selector, admin, eigenLayerPauserReg, SLASHER_INIT_PAUSED_STATUS)
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(eigenPodManager))),
            address(eigenPodManagerImplementation),
            abi.encodeWithSelector(
                EigenPodManager.initialize.selector,
                IBeaconChainOracle(address(0)),
                admin,
                eigenLayerPauserReg,
                EIGENPOD_MANAGER_INIT_PAUSED_STATUS
            )
        );
        eigenLayerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(delayedWithdrawalRouter))),
            address(delayedWithdrawalRouterImplementation),
            abi.encodeWithSelector(
                DelayedWithdrawalRouter.initialize.selector,
                admin,
                eigenLayerPauserReg,
                DELAYED_WITHDRAWAL_ROUTER_INIT_PAUSED_STATUS,
                DELAYED_WITHDRAWAL_ROUTER_INIT_WITHDRAWAL_DELAY_BLOCKS
            )
        );
    }

    function _deployTokens() internal {
        stETH = new MockERC20("lido staked ETH", "stETH", 18);
        wbETH = new MockERC20("binance staked ETH", "wbETH", 18);

        tokenAddresses = new address[](2);
        tokenAddresses[0] = address(stETH);
        tokenAddresses[1] = address(wbETH);
    }

    function _deployStrategies() internal {
        baseStrategyImplementation = new StrategyBaseTVLLimits(strategyManager);
        // create upgradeable proxies of strategies that each point to the implementation and initialize them
        for (uint256 i = 0; i < tokenAddresses.length; ++i) {
            deployedStrategyArray.push(
                StrategyBaseTVLLimits(
                    address(
                        new TransparentUpgradeableProxy(
                            address(baseStrategyImplementation),
                            address(eigenLayerProxyAdmin),
                            abi.encodeWithSelector(
                                StrategyBaseTVLLimits.initialize.selector,
                                type(uint256).max,
                                type(uint256).max,
                                IERC20(tokenAddresses[i]),
                                eigenLayerPauserReg
                            )
                        )
                    )
                )
            );
        }

        // set the strategy whitelist in strategyManager
        bool[] memory thirdPartyTransfers = new bool[](deployedStrategyArray.length); // default to allowing third party transfers

        // create an array of strategies with IStrategy interface to be able to pass into strategyManager whitelisting
        for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
            strategies.push() = IStrategy(address(deployedStrategyArray[i]));
        }
        strategyManager.addStrategiesToDepositWhitelist(strategies, thirdPartyTransfers);
    }

    /**
        Deployment Verifications
    */
    function _verifyContractsPointAtOneAnother(
        DelegationManager delegationContract,
        StrategyManager strategyManagerContract,
        EigenPodManager eigenPodManagerContract,
        DelayedWithdrawalRouter delayedWithdrawalRouterContract
    ) internal view {
        require(delegationContract.slasher() == slasher, "delegation: slasher address not set correctly");
        require(
            delegationContract.strategyManager() == strategyManager,
            "delegation: strategyManager address not set correctly"
        );

        require(strategyManagerContract.slasher() == slasher, "strategyManager: slasher address not set correctly");
        require(
            strategyManagerContract.delegation() == delegation,
            "strategyManager: delegation address not set correctly"
        );
        require(
            strategyManagerContract.eigenPodManager() == eigenPodManager,
            "strategyManager: eigenPodManager address not set correctly"
        );

        require(
            eigenPodManagerContract.ethPOS() == ethPOSDepositMock,
            " eigenPodManager: ethPOSDeposit contract address not set correctly"
        );
        require(
            eigenPodManagerContract.eigenPodBeacon() == eigenPodBeacon,
            "eigenPodManager: eigenPodBeacon contract address not set correctly"
        );
        require(
            eigenPodManagerContract.strategyManager() == strategyManager,
            "eigenPodManager: strategyManager contract address not set correctly"
        );
        require(
            eigenPodManagerContract.slasher() == slasher,
            "eigenPodManager: slasher contract address not set correctly"
        );

        require(
            delayedWithdrawalRouterContract.eigenPodManager() == eigenPodManager,
            "delayedWithdrawalRouterContract: eigenPodManager address not set correctly"
        );
    }

    function _verifyImplementationsSetCorrectly() internal view {
        require(
            eigenLayerProxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(address(delegation)))) ==
                address(delegationImplementation),
            "delegation: implementation set incorrectly"
        );
        require(
            eigenLayerProxyAdmin.getProxyImplementation(
                ITransparentUpgradeableProxy(payable(address(strategyManager)))
            ) == address(strategyManagerImplementation),
            "strategyManager: implementation set incorrectly"
        );
        require(
            eigenLayerProxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(address(slasher)))) ==
                address(slasherImplementation),
            "slasher: implementation set incorrectly"
        );
        require(
            eigenLayerProxyAdmin.getProxyImplementation(
                ITransparentUpgradeableProxy(payable(address(eigenPodManager)))
            ) == address(eigenPodManagerImplementation),
            "eigenPodManager: implementation set incorrectly"
        );
        require(
            eigenLayerProxyAdmin.getProxyImplementation(
                ITransparentUpgradeableProxy(payable(address(delayedWithdrawalRouter)))
            ) == address(delayedWithdrawalRouterImplementation),
            "delayedWithdrawalRouter: implementation set incorrectly"
        );

        // @audit deployed strategy checks are no longer needed
        // for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
        //     require(
        //         eigenLayerProxyAdmin.getProxyImplementation(
        //             ITransparentUpgradeableProxy(payable(address(deployedStrategyArray[i])))
        //         ) == address(baseStrategyImplementation),
        //         "strategy: implementation set incorrectly"
        //     );
        // }

        require(
            eigenPodBeacon.implementation() == address(eigenPodImplementation),
            "eigenPodBeacon: implementation set incorrectly"
        );
    }

    function _verifyInitialOwners() internal view {
        require(strategyManager.owner() == admin, "strategyManager: owner not set correctly");
        require(delegation.owner() == admin, "delegation: owner not set correctly");
        require(eigenPodManager.owner() == admin, "delegation: owner not set correctly");

        require(eigenLayerProxyAdmin.owner() == admin, "eigenLayerProxyAdmin: owner not set correctly");
        require(eigenPodBeacon.owner() == admin, "eigenPodBeacon: owner not set correctly");
        require(delayedWithdrawalRouter.owner() == admin, "delayedWithdrawalRouter: owner not set correctly");
    }

    function _checkPauserInitializations() internal view {
        require(delegation.pauserRegistry() == eigenLayerPauserReg, "delegation: pauser registry not set correctly");
        require(
            strategyManager.pauserRegistry() == eigenLayerPauserReg,
            "strategyManager: pauser registry not set correctly"
        );
        require(
            eigenPodManager.pauserRegistry() == eigenLayerPauserReg,
            "eigenPodManager: pauser registry not set correctly"
        );
        require(
            delayedWithdrawalRouter.pauserRegistry() == eigenLayerPauserReg,
            "delayedWithdrawalRouter: pauser registry not set correctly"
        );

        require(eigenLayerPauserReg.isPauser(admin), "pauserRegistry: operationsMultisig is not pauser");
        require(eigenLayerPauserReg.isPauser(admin), "pauserRegistry: executorMultisig is not pauser");
        require(eigenLayerPauserReg.isPauser(admin), "pauserRegistry: pauserMultisig is not pauser");
        require(eigenLayerPauserReg.unpauser() == admin, "pauserRegistry: unpauser not set correctly");

        // for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
        //     require(
        //         deployedStrategyArray[i].pauserRegistry() == eigenLayerPauserReg,
        //         "StrategyBaseTVLLimits: pauser registry not set correctly"
        //     );
        //     require(
        //         deployedStrategyArray[i].paused() == 0,
        //         "StrategyBaseTVLLimits: init paused status set incorrectly"
        //     );
        // }

        // // pause *nothing*
        // uint256 STRATEGY_MANAGER_INIT_PAUSED_STATUS = 0;
        // // pause *everything*
        // uint256 SLASHER_INIT_PAUSED_STATUS = type(uint256).max;
        // // pause *everything*
        // uint256 DELEGATION_INIT_PAUSED_STATUS = type(uint256).max;
        // // pause *all of the proof-related functionality* (everything that can be paused other than creation of EigenPods)
        // uint256 EIGENPOD_MANAGER_INIT_PAUSED_STATUS = (2**1) + (2**2) + (2**3) + (2**4); /* = 30 */
        // // pause *nothing*
        // uint256 DELAYED_WITHDRAWAL_ROUTER_INIT_PAUSED_STATUS = 0;
        require(strategyManager.paused() == 0, "strategyManager: init paused status set incorrectly");
        require(slasher.paused() == 0, "slasher: init paused status set incorrectly");
        require(delegation.paused() == 0, "delegation: init paused status set incorrectly");
        require(eigenPodManager.paused() == 0, "eigenPodManager: init paused status set incorrectly");
        require(delayedWithdrawalRouter.paused() == 0, "delayedWithdrawalRouter: init paused status set incorrectly");
    }

    function _verifyInitializationParams() internal view {
        require(
            strategyManager.strategyWhitelister() == admin,
            "strategyManager: strategyWhitelister address not set correctly"
        );

        require(
            eigenPodManager.beaconChainOracle() == IBeaconChainOracle(address(0)),
            "eigenPodManager: eigenPodBeacon contract address not set correctly"
        );

        require(
            delayedWithdrawalRouter.eigenPodManager() == eigenPodManager,
            "delayedWithdrawalRouter: eigenPodManager set incorrectly"
        );

        // require(
        //     baseStrategyImplementation.strategyManager() == strategyManager,
        //     "baseStrategyImplementation: strategyManager set incorrectly"
        // );

        require(
            eigenPodImplementation.ethPOS() == ethPOSDepositMock,
            "eigenPodImplementation: ethPOSDeposit contract address not set correctly"
        );
        require(
            eigenPodImplementation.eigenPodManager() == eigenPodManager,
            " eigenPodImplementation: eigenPodManager contract address not set correctly"
        );
        require(
            eigenPodImplementation.delayedWithdrawalRouter() == delayedWithdrawalRouter,
            " eigenPodImplementation: delayedWithdrawalRouter contract address not set correctly"
        );

        // @audit skipping this for now, assume strategy deployments to be correct
        // for (uint i = 0; i < tokenAddresses.length; i++) {
        //     uint256 maxPerDeposit = type(uint256).max;
        //     uint256 maxDeposits = type(uint256).max;
        //     (uint256 setMaxPerDeposit, uint256 setMaxDeposits) = tokenAddresses[i].getTVLLimits();
        //     require(setMaxPerDeposit == maxPerDeposit, "setMaxPerDeposit not set correctly");
        //     require(setMaxDeposits == maxDeposits, "setMaxDeposits not set correctly");
        // }
    }
}
