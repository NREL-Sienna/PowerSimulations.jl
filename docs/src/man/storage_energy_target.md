# Energy Target Storage Formulation
This formulation provides a way for user to tackle the end of horizon effect in battery operation by adding a constraint on stored energy at the end of period. The target constraint includes a slack variable which is associated with a penalty for any violation of the constraints, this ensure feasibility of the model for scenarios where it is not optimal to exactly meet the target.

# Formulation Overview
 The features of this model are:
- Standard Battery Operation Constraint
  - Energy balance constraint
  - Energy range constraint
  - Charging and discharging limit constraint
- Power Contribution in eligible services 
- Stored Energy Target Constraint 


# Formulations
### Indices and Sets
```math
\begin{itemize}
	\item[$t \in \cT$] Hourly time steps: $1, \ldots, T$, $T$ = {\tt time\_periods}
    \item[$b \in \cB$] - Set of battery device.
    \item[$h \in \cH$]- Set of hydro reservoir device.
\end{itemize}
```
### Parameters
```math
\begin{itemize}
	\item[$C$]  Value of energy/penalty cost for device $b$ ($/MW).
    \item[$C^{value}(b)$] or [$C^{value}(h)$]  - Energy/Water value cost for battery/hydro devices at end of period
    \item[$C^{penalty}(b)$] or  [$C^{penalty}(h)$] - Penalty cost associated with unsatisfied energy target for battery/hydro devices.
    \item[$C^{var}(b)$] or [$C^{var}(h)$] - Variable cost of generation.
	\item[$\oP_in(b)$]   Maximum charging power input for device $b$ (MW), {\tt power\_input\_maximum}.
	\item[$\uP_in(b)$]   Minimum charging power input for device $b$ (MW), {\tt power\_input\_minimum}.
    \item[$\oP_out(b)$]   Maximum discharging power output for device $b$ (MW), {\tt power\_output\_maximum}.
	\item[$\uP_out(b)$]   Minimum discharging power output for device $b$ (MW), {\tt power\_output\_minimum}.
    \item[$\oE(b)$] Maximum state of charge limt for device $b$ (MWh), {\tt energy\_maximum}.
    \item[$\uE(b)$] Minimum state of charge limt for device $b$ (MWh), {\tt energy\_minimum}.
	\item[$I(b,t)$)] - Energy/Water inflow in the hydro reservoir at timestep ($t$) for hydro devices
    \item[$hat{E}(b,t)$)  or $\hat{E}(h,t)$) - Energy target at timestep ($t$) for battery/hydro devices for $t \in \hat{T}$.
	\item[$E(b)^0$]   Energy stored in device $b$ (MWh) in the time period prior to t=1, {\tt energy\_stored\_t0}.
\end{itemize}
```

### Variables
```math
\begin{itemize}
	\item[$p_in(b,t)$] Active power variable for charging  $b$ at time $t$, $\geq 0$.
	\item[$p_out(b, t)$]  Active power variable for discharging $b$ at time $t$, $\geq 0$.
	\item[$e(b, t)$] Stored energy variable for $b$ at time $t$, $\geq 0$.
	\item[$e_slack(b, t)$] Slack variable for energy target constraint for $b$ at time $t$,  $\geq 0$.
    \item[$s(h,t)$] - Energy/Water Spilled from a hydro reservoir devices
    \item[$e^{-}_{slack}(b,t)$]  or  [$e^{-}_{slack}(h,t)$] - Slack variable for energy target constraint for excess
    \item[$e^{+}_{slack}(b,t)$]  or  [$e^{+}_{slack}(h,t)$] - Slack variable for energy target constraint for shortage
\end{itemize}
```


### Model Description
This first model is for Power Systems Storage devices (e.g. GenericBattery, BatteryEMS) with StorageManagementCost.

*Objective Function*
```math
{\allowdisplaybreaks
\begin{align}
    & \text{min} \sum_{b, t \in \hat{\cT}} \quad [e^{+}_{slack}(b,t)*C^{penalty}(b) - e^{-}_{slack}(b,t)* C^{value}(b)] \label{eq:obj} %\tag{OBJ} %\\
\end{align}
}%
```
subject to:\

*Active power constraints*
```math
\begin{align}
		& p_in(b,t) + r_g(t) \leq  \oP_in(b) & \forall t \in \cT, \, \forall b \in \cB \label{eq:MaxInput} \\
		& p_in(b,t) + r_g(t) \geq  \uP_in(b) & \forall t \in \cT, \, \forall b \in \cB \label{eq:MinInput} \\
        & p_out(b,t) + r_g(t) \leq  \oP_out(b)& \forall t \in \cT, \, \forall b \in \cB \label{eq:MaxOutput} \\
		& p_out(b,t) + r_g(t) \geq  \uP_out(b)& \forall t \in \cT, \, \forall b \in \cB \label{eq:MinOutput} \\
\end{align}
```

*Energy Limit constraints*
```math
\begin{align}
		& e(b,t) \leq  \oE(b) & \forall t \in \cT, \, \forall b \in \cB \label{eq:MaxEnergyLimit} \\
		& e(b,t) \geq  \uE(b) & \forall t \in \cT, \, \forall b \in \cB \label{eq:MinEnergyLimit} \\
\end{align}
```

*Energy Balance/State of Charge constraint*
```math
\begin{align}
		& e(b,1) - E(b)^0 = p_in(b,1) - p_out(b,1) & \forall b \in \cB \label{eq:EnergyBalance0} \\
		& e(b,t) -e(b,t-1) = p_in(b,t) - p_out(b,t) & \forall t \in \cT\setminus\{1\}, \, \forall b \in \cB \label{eq:EnergyBalance} \\
\end{align}
```

*Energy Target constraint*
```math
\begin{align}
        & e(b,t) + e^{+}_{slack}(b,t) + e^{-}_{slack}(b,t) = \hat{E}(b,t) \quad \forall b \in \cB, t \in \hat{\cT} \label{eq:EnergyTarget} \\
\end{align}
```

*Energy slacks constraint*
```math
\begin{align}
		& e^{-}_{slack}(b,t) \leq 0.0 & \forall t \in \cT, \, \forall b \in \cB \label{eq:ShortageSlackBound} \\
		& e^{+}_{slack}(b,t) \geq 0.0 & \forall t \in \cT, \, \forall b \in \cB \label{eq:SurplusSlackBound} \\
\end{align}
```


### Hydro Storage Target Model Description
This model is for Power Systems HydroEnergyReservoir and HydroPumpedStorage devices with StorageManagementCost.

*Objective Function*
```math
{\allowdisplaybreaks
\begin{align}
    & \text{min}   \sum_{h,t} p(h,t) \cdot [C^{var}(h) + C^{fixed}(h)] \\
    + \sum_{h, t \in \hat{\cT}} \quad [e^{+}_{slack}(h,t) * C^{penalty}(h) - e^{-}_{slack}(h,t) * C^{value}(h)]   \label{eq:obj} %\tag{OBJ} %\\
\end{align}
}%
```
subject to:\

*Active power constraints*
```math
\begin{align}
		& p(h,t)  \leq  \oP(h) & \forall t \in \cT, \, \forall h \in \cH \label{eq:MinOutput} \\
		& p(h,t)  \geq  \uP(h) & \forall t \in \cT, \, \forall h \in \cH \label{eq:MinOutput} \\
        & s(h,t) \leq  \cS^{max}(h)& \forall t \in \cT, \, \forall h \in \cH \label{eq:MaxSpillage} \\
		& s(h,t) \geq  0 & \forall t \in \cT, \, \forall h \in \cH \label{eq:MinSpillage} \\
\end{align}
```

*Energy Limit constraints*
```math
\begin{align}
		& e(b,t) \leq  \oE(b) & \forall t \in \cT, \, \forall b \in \cB \label{eq:MaxEnergyLimit} \\
		& e(b,t) \geq  \uE(b) & \forall t \in \cT, \, \forall b \in \cB \label{eq:MinEnergyLimit} \\
\end{align}
```

*Energy Balance/State of Charge constraint*
```math
\begin{align}
		& e(h,1) - E(h)^0 = I(h,1) - p(h,1) - s(h,1) & \forall h \in \cH \label{eq:EnergyBalance0} \\
		& e(h,t) -e(h,t-1) = I(h,t) - p(h,t) - s(h,t) & \forall t \in \cT\setminus\{1\}, \, \forall h \in \cH \label{eq:EnergyBalance} \\
\end{align}
```

*Energy Target constraint*
```math
\begin{align}
        & e(h,t) + e^{+}_{slack}(h,t) + e^{-}_{slack}(h,t) = \hat{E}(h,t) \quad \forall h \in \cH, t \in \hat{\cT} \label{eq:EnergyTarget} \\
\end{align}
```

*Energy slacks constraint*
```math
\begin{align}
		& e^{-}_{slack}(h,t) \leq 0.0 & \forall t \in \cT, \, \forall h \in \cH \label{eq:ShortageSlackBound} \\
		& e^{+}_{slack}(h,t) \geq 0.0 & \forall t \in \cT, \, \forall h \in \cH \label{eq:SurplusSlackBound} \\
\end{align}
```

### Impact of different cost configurations
In the table we describe all possible configuration of the StorageManagementCost with the target constraint in hydro or storage device models. Cases 1(a) & 2(a) will have no impact of the models operations and the target constraint will be rendered useless. In most cases that have no energy target and a non-zero value for $C^{value}$, if this cost is too high ($C^{value} >> 0$) or too low ($C^{value} <<0$) can result in either the model holding on to stored energy till the end or the model not storing any energy in the device. This is caused by the fact that when energy target is zero, we have $e(t) = - e^{-}_{shortage}(t)$, and  $- e^{-}_{shortage} * C^{value}$ in the objective function is replaced by $e(t) * C^{value}$, thus resulting in $C^{value}$ to be seen as the cost of stored energy.

```math
\begin{table}
% \caption{}
\begin{tabular}{ |p{1.5cm}||p{1.5cm}|p{2cm}|p{2cm}|p{5cm}| }
 \hline
 \multicolumn{5}{|c|}{Scenario List} \\
 \hline
Case & Energy Target & Energy Shortage Cost & Energy Value / Energy Surplus cost& Effect \\
 \hline
 Case 1(a) & $\hat{E}=0$    & $C^{penalty}=0$   & $C^{value}=0$& no change\\[-1.5ex]
 \hline\\[-1.5ex]
 Case 1(b) & $\hat{E}=0$    & $C^{penalty}=0$   & $C^{value}<0$& penalty for storing energy\\
 Case 1(c) & $\hat{E}=0$    & $C^{penalty}>0$   & $C^{value}=0$& no penalties or incentives applied\\
 Case 1(d) & $\hat{E}=0$    & $C^{penalty}=0$   & $C^{value}>0$& incentive for storing energy \\
 Case 1(e) & $\hat{E}=0$    & $C^{penalty}>0$   & $C^{value}<0$& penalty for storing energy \\
 Case 1(f) & $\hat{E}=0$    & $C^{penalty}>0$   & $C^{value}>0$& incentive for storing energy \\
 \hline
 Case 2(a) & $\hat{E}>0$    & $C^{penalty}=0$   & $C^{value}=0$& no change\\[-1.5ex]
 \hline\\[-1.5ex]
 Case 2(b) & $\hat{E}>0$    & $C^{penalty}=0$   & $C^{value}<0$& penalty on energy storage in excess of target  \\
 Case 2(c) & $\hat{E}>0$    & $C^{penalty}>0$   & $C^{value}=0$& penalty on energy storage short of target\\
 Case 2(d) & $\hat{E}>0$    & $C^{penalty}=0$   & $C^{value}>0$& incentive on excess energy \\
 Case 2(e) & $\hat{E}>0$    & $C^{penalty}>0$   & $C^{value}<0$& penalty on both  excess/shortage of energy\\
 Case 2(f) & $\hat{E}>0$    & $C^{penalty}>0$   & $C^{value}>0$& penalty for shortage, incentive for excess energy \\
 \hline
\end{tabular}
\caption{\label{tab:table-name} Table above describes the different effects that can be induced into the model using the target constraint formulation.}
\end{table}
```
