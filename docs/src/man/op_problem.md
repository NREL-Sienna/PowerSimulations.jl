## Operational Model

An operational model is defined as the combination of an objective function (\refeq{g_psimulations}) in terms of state $x$ and control $u$ variables. Equations (\refeq{d_psimulations}) describe the device model formulations as a function of variables, parameters $\eta$ and uncertainty terms $\omega$. Further, equations (\refeq{n_psimulations}) represents the network modeling and finally the system services.

In the same fashion as in `PowerSystems.jl`, the objective is not to list all possible formulations for devices, network, and services in a power system model. Rather, the contribution is to develop a type hierarchy that enables developers to create new formulations and allow analysts a  natural way to describe the functional assumptions used in the model.
