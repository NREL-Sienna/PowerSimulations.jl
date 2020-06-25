# Power Grid Lib - Unit Commitment / Multi-Start Unit Commitment
This formulation is from the benchmark library maintained by the IEEE PES Task Force on Benchmarks for Validation of Emerging Power System Algorithms and is designed to evaluate a well established version of the the Unit Commitment problem.

# Formulation Overview
 The features of this model are:
- A global load requirement with time series
- An optional global spinning reserve requirement with time series
- Thermal generators with technical parameters, including
  - Minimum and maximum power output
  - Hourly ramp-up and ramp-down rates
  - Start-up and shut-down ramp rates
  - Minimum run-times and off-times
  - Upto 3 types of startup types (hot, warm, cold)
  - Off time dependent start-up costs
  - Startup & Shutdown lag/power trajectory constraint
  - Piecewise linear convex production costs
  - Must run constraints
  - No-load costs
- Optional renewable generators with time series for minimum and maximum production.


# Formultions 
A detailed description of this mathematical model is available here. This model does have some aaugmentation to constraints but is mathematically equivalent to the formulation found [here](https://github.com/power-grid-lib/pglib-uc/blob/master/MODEL.pdf). 
### Indices and Sets
```math
\begin{itemize}
	\item[$g \in \cG$] Set of thermal generators.
	\item[$g \in \cG_{\textit{on}}^0$] Set of thermal generators which are initially committed (on).
	\item[$g \in \cG_{\textit{off}}^0$] Set of thermal generators which are not initially committed (off).
	\item[$w \in \cW$] Set of renewable generators.
	\item[$t \in \cT$] Hourly time steps: $1, \ldots, T$, $T$ = {\tt time\_periods}
	\item[$l \in \cL_g$] Piecewise production cost intervals for thermal generator $g$: $1, \ldots, L_g$.
	\item[$s \in \cS_g$] Startup categories for thermal generator $g$, from hottest ($1$) to coldest ($S_g$): $1, \ldots, S_g$.
\end{itemize}
```

### System Parameters
```math
\begin{itemize}
	\item[$D(t)$]    Load (demand) at time $t$ (MW), {\tt demand}.
	\item[$R(t)$]    Spinning reserve at time $t$ (MW), {\tt reserves}.
\end{itemize}
```

### Thermal Generator Parameters
```math
\begin{itemize}
	\item[$CS_g^s$]  Startup cost in category $s$ for generator $g$ (\$), {\tt startup['cost']}.
	\item[$CP_g^l$]  Cost of operating at piecewise generation point $l$ for generator $g$ (MW), {\tt piecewise\_production['cost']}.
	\item[$DT_g$]    Minimum down time for generator $g$ (h), {\tt time\_down\_minimum}.
	\item[$DT^0_g$] Number of time periods the unit has been off prior to the first time period for generator $g$, {\tt time\_down\_t0}.
	\item[$\oP_g$]   Maximum power output for generator $g$ (MW), {\tt power\_output\_maximum}.
	\item[$\uP_g$]   Minimum power output for generator $g$ (MW), {\tt power\_output\_minimum}.
	\item[$P_g^0$]   Power output for generator $g$ (MW) in the time period prior to t=1, {\tt power\_output\_t0}.
	\item[$P_g^l$]   Power level for piecewise generation point $l$ for generator $g$ (MW); $P^1_g = \uP_g$ and $P^{L_g}_g = \oP_g$, {\tt piecewise\_production['mw']}.
	\item[$RD_g$]    Ramp-down rate for generator $g$ (MW/h), {\tt ramp\_down\_limit}.
	\item[$RU_g$]    Ramp-up rate for generator $g$ (MW/h), {\tt ramp\_up\_limit}.
	\item[$SD_g$]    Shutdown capability for generator $g$ (MW), {\tt ramp\_shutdown\_limit}.
	\item[$SU_g$]    Startup capability for generator $g$ (MW), {\tt ramp\_startup\_limit}
	\item[$TS^s_g$] Time offline after which the startup category $s$ becomes active (h), {\tt startup['lag']}.
	\item[$UT_g$]    Minimum up time for generator $g$ (h), {\tt time\_up\_minimum}.
	\item[$UT^0_g$] Number of time periods the unit has been on prior to the first time period for generator $g$, {\tt time\_up\_t0}.
	\item[$U_g^0$]  Initial on/off status for generator $g$, $U_g^0=1$ for $g \in \cG_{\textit{on}}^0$, $U_g^0=0$ for $g \in \cG_{\textit{off}}^0$,  {\tt unit\_on\_t0}.
	\item[$U_g$] 	Must-run status for generator $g$, {\tt must\_run}.
\end{itemize}
```

### Renewable Generator Parameters
```math
\begin{itemize}
	\item[$\oP_w(t)$] Maximum renewable generation available from renewable generator $w$ at time $t$ (MW), {\tt power\_output\_maximum}.
	\item[$\uP_w(t)$] Minimum renewable generation available from renewable generator $w$ at time $t$ (MW), {\tt power\_output\_minimum}.
\end{itemize}
```

### Variables
```math
\begin{itemize}
	\item[$c_g(t)$]    Cost of power produced above minimum for thermal generator $g$ at time $t$ (MW), $\in \bbR$.
	\item[$p_g(t)$]    Power above minimum for thermal generator $g$ at time $t$ (MW), $\geq 0$.
	\item[$p_w(t)$]  Renewable generation used from renewable generator $w$ at time $t$ (MW), $\geq 0$.
	\item[$r_g(t)$]    Spinning reserves provided by thermal generator $g$ at time $t$ (MW), $\geq 0$.
	\item[$u_g(t)$]    Commitment status of thermal generator $g$ at time $t$, $\in \{0,1\}$. 
	\item[$v_g(t)$]    Startup status of thermal generator $g$ at time $t$, $\in \{0,1\}$. 
	\item[$w_g(t)$]    Shutdown status of thermal generator $g$ at time $t$, $\in \{0,1\}$. \
	\item[$\delta^s_g(t)$] Startup in category $s$ for thermal generator $g$ at time $t$, $\in \{0,1\}$.
	\item[$\lambda_g^l(t)$]  Fraction of power from piecewise generation point $l$ for generator $g$ at time $t$ (MW), $\in [0,1]$.
\
\end{itemize}
```

### Model Description
Below we describe the unit commitment model given by~\cite{morales2013tight}, with the piecewise production cost description from~\cite{sridhar2013locally}.
The unit commitment problem can then be formulated as:\
*Objective Function*
```math
{\allowdisplaybreaks
\begin{align}
    & \text{min } \sum_{g \in \cG} \sum_{t \in \cT} \left( c_g(t) + CP_g^1 \, u_g(t) + \sum_{s = 1}^{S_g} \left( CS^s_g \delta^s(t) \right) \right) \label{eq:obj} %\tag{UC} %\\
\end{align}
}%
```
subject to:\
*Demand and Reserve Balance constraints*
```math
\begin{align}
		& \sum_{g \in \cG} \left( p_g(t) + \uP_g u_g(t) \right) + \sum_{w\in\cW} p_w(t) = D(t) & \hspace{5cm} \forall t \in \cT \label{eq:UCDemand} \\
		& \sum_{g \in \cG} r_g(t) \geq R(t) &  \forall t \in \cT \label{eq:UCReserves}
\end{align}
```
*Active power constraints with Startup/Shutdown lag*
```math
\begin{align}
		& U_g^0(P_g^0-\uP_g) \leq (\oP_g - \uP_g) U_g^0 - \max\{(\oP_g - SD_g),0\} w_g(1) & \forall g \in \cG \label{eq:MaxOutput2Init}
		& p_g(t) + r_g(t) \leq (\oP_g - \uP_g) u_g(t) - \max\{(\oP_g - SU_g),0\} v_g(t) & \forall t \in \cT, \, \forall g \in \cG \label{eq:MaxOutput1} \\
		& p_g(t) + r_g(t) \leq (\oP_g - \uP_g) u_g(t) - \max\{(\oP_g - SD_g),0\} w_g(t+1) & \forall t \in \cT\setminus \{T\}, \, \forall g \in \cG \label{eq:MaxOutput2}
\end{align}
```
*Ramp constraints*
```math
\begin{align}
		& p_g(1) + r_g(1) - U_g^0(P_g^0-\uP_g) \leq RU_g & \forall g \in \cG \label{eq:RampUpInit} \\
		& U_g^0(P_g^0-\uP_g) - p_g(1) \leq RD_g & \forall g \in \cG \label{eq:RampDownInit} \\
		& p_g(t) + r_g(t) - p_g(t-1) \leq RU_g & \forall t \in \cT\setminus\{1\}, \, \forall g \in \cG \label{eq:RampUp} \\
		& p_g(t-1) - p_g(t) \leq RD_g & \forall t \in \cT\setminus\{1\}, \, \forall g \in \cG \label{eq:RampDown}
\end{align}
```
*Unit Commitment constraint*
```math
\begin{align}
		& u_g(1) - U_g^0 = v_g(1) - w_g(1) & \forall g \in \cG \label{eq:LogicalInitial} \\
		& u_g(t) - u_g(t-1) = v_g(t) - w_g(t) & \forall t \in \cT\setminus\{1\}, \, \forall g \in \cG \label{eq:Logical} \\
\end{align}
```

*Minimum Uptime constraints*
```math
\begin{align}
		& UT_g w_g(t) - \sum_{i=t-UT_g + 1}^t u_g(i) - UT_g^0 \leq 0 & \forall t \in \{1 \ldots, \min\{UT_g,T\}\}, \, \forall g \in \cG \label{eq:StartupInit} \\
		& \sum_{i= t-\min\{UT_g,T\} + 1}^t v_g(i) \leq u_g(t) & \forall t \in \{\min\{UT_g,T\} \ldots, T\}, \, \forall g \in \cG \label{eq:Startup}
\end{align}
```

*Minimum Downtime constraints*
```math
\begin{align}
		& DT_g v_g(t) - \sum_{i=t-DT_g + 1}^t u_g(i) - DT_g^0 \leq 0 & \forall t \in \{1 \ldots, \min\{DT_g,T\}\}, \, \forall g \in \cG \label{eq:ShutdownInit} \\
		& \sum_{i= t-\min\{DT_g,T\} + 1}^t w_g(i) \leq 1 - u_g(t) & \forall t \in \{\min\{DT_g, T\}, \ldots, T\}, \, \forall g \in \cG \label{eq:Shutdown}
\end{align}
```

*Must run constriant*
```math
\begin{align}
		& u_g(t) \geq U_g & \hspace{1cm} \forall t \in \cT, \, \forall g \in \cG \label{eq:MustRun}
\end{align}
```
*Start-up timelimits constraints*
```math
\begin{align}
		& \delta^s_g(t) \leq \sum_{i = TS^s_g}^{TS^{s+1}_g-1} w_g(t-i) & \forall t \in \{TS^{s+1}_g,\ldots,T\},\,\forall s \in \cS_g\!\setminus\!\{S_g\},\,  \forall g \in \cG \label{eq:STISelect}
\end{align}
```

*Start-up type selection constriant*
```math
\begin{align}
		& v_g(t) = \sum_{s = 1}^{S_g} \delta^s_g(t) & \forall t \in \cT,\, \forall g \in \cG \label{eq:STILink}
\end{align}
```

*Start-up initial condition constraints*
```math
\begin{align}
		& (TS^{s+1}_g - 1)\delta^s_g(t) + (1 - \delta^s_g(t)) M \geq \sum_{i = 1}^{t} u_g(i) + DT_g^0 & \forall t \in \{1,\ldots,TS^{s+1}_g -1\},\, \forall g \in \cG \label{eq:STInitUB}
		& TS^{s}_g \delta^s_g(t)  \leq \sum_{i = 1}^{t} u_g(i) + DT_g^0 & \forall t \in \{1,\ldots,TS^{s+1}_g-1\},\, \forall g \in \cG \label{eq:STInitLB}
\end{align}
```

*Piecewise Cost Constraint*
```math
\begin{align}
		& p_g(t) = \sum_{l \in \cL_g} (P_g^l - P_g^1) \lambda_g^l(t) &\hspace{5cm} \forall t \in \cT, \, \forall g \in \cG \label{eq:PiecewiseParts} \\
		& c_g(t) = \sum_{l \in \cL_g} (CP_g^l - CP_g^1) \lambda_g^l(t) & \forall t \in \cT, \, \forall g \in \cG \label{eq:PiecewisePartsCost} \\
		& u_g(t) = \sum_{l \in \cL_g} \lambda_g^l(t) & \forall t \in \cT, \forall g \in \cG \label{eq:PiecewiseLimits}
\end{align}
```

*Active power limits*
```math
\begin{align}
		& \uP_w(t) \leq p_w(t) \leq \oP_w(t) &\hspace{6cm} \forall t \in \cT, \, \forall w \in \cW \label{eq:WindLimit}
\end{align}
```

# References

[1] Knueven, Bernard, James Ostrowski, and Jean-Paul Watson. "On mixed integer programming formulations for the unit commitment problem." Pre-print available at http://www.optimization-online.org/DB_HTML/2018/11/6930.pdf (2018).

[2] Krall, Eric, Michael Higgins, and Richard P. O’Neill. "RTO unit commitment test system." Federal Energy Regulatory Commission. Available: http://ferc.gov/legal/staff-reports/rto-COMMITMENT-TEST.pdf (2012).
