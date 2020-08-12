# Hydro Generation Models

Here we present the mathematical formulation of the different models for Hydro Generation.

### Dispatch Run of River ```[HydroDispatchRunOfRiver]```

The following model provides upper bounds for the active power based on run of the river inflow, modeled as a ``\eta_t \in [0,1]`` coefficient of the maximum active power. Additional bounds for reactive power are considered.

```math
\begin{align}
&  P^\text{min} \le P_t \le \eta_t P^\text{max} \\
&  Q^\text{min} \le Q_t \le Q^\text{max}
\end{align}
```

### Dispatch Energy Budget ```[HydroDispatchReservoirBudget]```
The following model provides an energy budget over the time horizon for the active power.

```math
\begin{align}
&  \sum_{t = 1}^N P_t \cdot \Delta T \le E^\text{budget} \\
&  P^\text{min} \le P_t \le P^\text{max} \\
&  Q^\text{min} \le Q_t \le Q^\text{max}
\end{align}
```

### Dispatch Storage ```[HydroDispatchReservoirStorage]```

The following model includes a energy level ``E_t`` to handle the storage energy. Inflow power``I_t`` can also be included as time series into the balance equation. Spillage ``S_t`` is also considered:

```math
\begin{align}
&  E_{t+1} = E_t + (I_t - S_t - P_t)\Delta T \\
&  P^\text{min} \le P_t \le P^\text{max} \\
&  Q^\text{min} \le Q_t \le Q^\text{max}
\end{align}
```

Future releases will also implement a requirement of the energy at the last time point ``N``:
```math
\begin{align}
& E_N \ge E^\text{requirement}
\end{align}
```


### Commitment Run of River ```[HydroCommitmentRunOfRiver]```

Similar to the dispatch formulation, but considering a binary variable ``u_t \in \{0, 1\}`` with semi continuous constraints for both active and reactive power:

```math
\begin{align}
&  P_t \le \eta_t P^\text{max}\\
&  P_t - u_t P^\text{max} \le 0 \\
&  P_t - u_t P^\text{min} \ge 0 \\
&  Q_t - u_t Q^\text{max} \le 0 \\
&  Q_t - u_t Q^\text{min} \ge 0
\end{align}
```


### Commitment Energy Budget ```[HydroCommitmentReservoirBudget]```

Similar to the dispatch formulation, but considering a binary variable ``u_t \in \{0, 1\}`` with semi continuous constraints for both active and reactive power:

```math
\begin{align}
&  \sum_{t = 1}^N P_t \cdot \Delta T \le E^\text{budget} \\
&  P_t - u_t P^\text{max} \le 0 \\
&  P_t - u_t P^\text{min} \ge 0 \\
&  Q_t - u_t Q^\text{max} \le 0 \\
&  Q_t - u_t Q^\text{min} \ge 0
\end{align}
```

### Commitment Energy Budget ```[HydroCommitmentReservoirStorage]```

Similar to the dispatch formulation, but considering a binary variable ``u_t \in \{0, 1\}`` with semi continuous constraints for both active and reactive power:

```math
\begin{align}
&  E_{t+1} = E_t + (I_t - S_t - P_t)\Delta T \\
&  P_t - u_t P^\text{max} \le 0 \\
&  P_t - u_t P^\text{min} \ge 0 \\
&  Q_t - u_t Q^\text{max} \le 0 \\
&  Q_t - u_t Q^\text{min} \ge 0
\end{align}
```