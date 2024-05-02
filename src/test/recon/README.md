## Purpose

This repository will acts as a base entrypoint to the EigenLayer system.

It will allow full end-to-end testing for protocols integrating with EigenLayer by providing an interface to interact with the EigenLayer system in their fuzz testing suite.

This is made possible via the `deployEigenLayer` function which has two options: 
1. it can deploy the entire system locally with parameters passed in by the integrating test suite
2. it forks the existing system state from mainnet and exposes an interface that allows the integrating suite to modify the system state locally
