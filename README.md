## EigenLayer Fuzzing

### Purpose
This repository acts as a base entrypoint to the EigenLayer system, allowing full end-to-end testing for protocols integrating with EigenLayer by providing an interface to EigenLayer via the `EigenLayerSystem` contract. 

By deploying the entire EigenLayer system you can skip the need to create mocks of EigenLayer contracts and directly integrate into a suite using Echidna/Medusa/Foundry for fuzzing/unit testing. 

### To use 
The `deployEigenLayerLocal` function in `EigenLayerSystem` deploys a local version of EigenLayer with two token strategies (stETH and wbETH) and makes it inheritable into your testing suite.

In a Foundry project add this repository as a submodule with: 

```bash 
forge install Recon-Fuzz/eigenlayer-fuzzing
```

Inherit the `EigenLayerSystem` contract into the `Setup` or test contract of the fuzzing/testing suite.

Ex (fuzzing suite):

```solidity
contract RenzoSetup is EigenLayerSystem {}
```

Call the `deployEigenLayerLocal` function somewhere in your system setup. You will now have all EigenLayer contracts accessible as internal state variables which can be called to set values for your integrating system, but won't be targeted by Echidna/Medusa. 

### Working Example

See [this Renzo-Fuzzing repo](https://github.com/Recon-Fuzz/renzo-fuzzing) for a working example of how to integrate this repo into a fuzzing suite.

### Externalities
The following economic externalities have been added to the EigenLayerSystem contract to facilitate testing these sorts of events in integrating protocols. 

- [Native ETH slashing](https://github.com/Recon-Fuzz/eigenlayer-fuzzing/blob/4416d89454aa1d201a101bca90c24100e9434141/src/test/recon/EigenLayerSystem.sol#L16-L25)
- [AVS slashing](https://github.com/Recon-Fuzz/eigenlayer-fuzzing/blob/4416d89454aa1d201a101bca90c24100e9434141/src/test/recon/EigenLayerSystem.sol#L29-L65)
