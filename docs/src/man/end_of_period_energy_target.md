# End-of-Period Energy Target Storage Formulation
This formulation provide a way for user to tackle the end of horizon effect in battery opertaion by adding a constraint on stored energy at the end of period. The target constraint includes a slack variable which is associated with a penalty for any violation of the constraints, this ensure feasibility of the model for scenarios where it not optimal to excatly meet the target.

# Formulation Overview
 The features of this model are:
- Standard Battery Operation Constraint
  - Energy balance constraint
  - Energy range constraint
  - Charging and discharing limit constraint
- Power Contribution in eligible services 
- End-of-Period Energy Target Constraint 


# Formulations
### Indices and Sets
```math
\begin{itemize}
	\item[$b \in \cB$] Set of battery devices.
	\item[$t \in \cT$] Hourly time steps: $1, \ldots, T$, $T$ = {\tt time\_periods}
\end{itemize}
```
### Parameters
```math
\begin{itemize}
	\item[$C$]  Value of energy/penalty cost for device $b$ ($/MW).
	\item[$\oP_in(b)$]   Maximum charging power input for device $b$ (MW), {\tt power\_input\_maximum}.
	\item[$\uP_in(b)$]   Minimum charging power input for device $b$ (MW), {\tt power\_input\_minimum}.
    \item[$\oP_out(b)$]   Maximum discharging power output for device $b$ (MW), {\tt power\_output\_maximum}.
	\item[$\uP_out(b)$]   Minimum discharging power output for device $b$ (MW), {\tt power\_output\_minimum}.
    \item[$\oE(b)$] Maximum state of charge limt for device $b$ (MWh), {\tt energy\_maximum}.
    \item[$\uE(b)$] Minimum state of charge limt for device $b$ (MWh), {\tt energy\_minimum}.
	\item[$ET(b)$] End of period energy target for device $b$ (MWh).
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
\end{itemize}
```


### Model Description

*Objective Function*
```math
{\allowdisplaybreaks
\begin{align}
    & \text{min } \sum_{b \in \cB} \sum_{t \in \cT} \left( e_slack(b, t) + C \right) \label{eq:obj} %\tag{OBJ} %\\
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

*End of Period Energy Target constraint*
```math
\begin{align}
		& e(b,T) + e_slack(b,T) = ET(b) & \forall b \in \cB \label{eq:EnergyTarget} \\
\end{align}
```
