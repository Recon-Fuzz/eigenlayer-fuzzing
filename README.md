## EigenLayer Fuzzing

### Purpose
This repository acts as a base entrypoint to the EigenLayer system, allowing full end-to-end testing for protocols integrating with EigenLayer by providing an interface to interact with the EigenLayer system via the EigenLayerSystem contract.

This is made possible via the `deployEigenLayerLocal` function which deploys the entire EigenLayer system and makes it inheritable into a fuzzing/testing suite for protocols building on top of EigenLayer.

### Externalities
The following economic externalities have been added to the EigenLayerSystem contract to facilitate testing these sorts of events in integrating protocols. 

- Native ETH slashing
- AVS slashing

### To use 
In a foundry project add this repository as a submodule with: 

```bash 
forge install nican0r/eigenlayer-fuzzing
```

Inherit the `EigenLayerSystem` contract into the `Setup` contract of the fuzzing/testing suite.

Ex:

```solidity
contract RenzoSetup is EigenLayerSystem {}
```

Call the `deployEigenLayerLocal` function somewhere in your system setup. You will now have all the entire EigenLayer system accessible to you as internal state variables which can be called by your target functions but won't be targeted by Echidna or Medusa. 


### Working Example

See this Renzo-Fuzzing repo for a working example.
