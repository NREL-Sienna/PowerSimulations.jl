# `PowerSystems.Branch` Formulations

!!! note
    
    The use of reactive power variables and constraints will depend on the network model used, i.e., whether it uses (or does not use) reactive power. If the network model is purely active power-based, reactive power variables and related constraints are not created.

### Table of contents

 1. [`StaticBranch`](#StaticBranch)
 2. [`StaticBranchBounds`](#StaticBranchBounds)
 3. [`StaticBranchUnbounded`](#StaticBranchUnbounded)
 4. [`HVDCTwoTerminalUnbounded`](#HVDCTwoTerminalUnbounded)
 5. [`HVDCTwoTerminalLossless`](#HVDCTwoTerminalLossless)
 6. [`HVDCTwoTerminalDispatch`](#HVDCTwoTerminalDispatch)
 7. [`HVDCTwoTerminalPiecewiseLoss`](#HVDCTwoTerminalPiecewiseLoss)
 8. [`HVDCTwoTerminalVSCLoss`](#HVDCTwoTerminalVSCLoss)
 9. [`HVDCTwoTerminalVSCLossBilinear`](#HVDCTwoTerminalVSCLossBilinear)
10. [`HVDCTwoTerminalVSCLossQuadratic`](#HVDCTwoTerminalVSCLossQuadratic)
11. [`PhaseAngleControl`](#PhaseAngleControl)
12. [Valid configurations](#Valid-configurations)

## `StaticBranch`

Formulation valid for `PTDFPowerModel` Network model

```@docs
StaticBranch
```

**Variables:**

  - [`FlowActivePowerVariable`](@ref):
    
      + Bounds: ``(-\infty,\infty)``
      + Symbol: ``f``
        If Slack variables are enabled:

  - [`FlowActivePowerSlackUpperBound`](@ref):
    
      + Bounds: [0.0, ]
      + Default proportional cost: 2e5
      + Symbol: ``f^\text{sl,up}``
  - [`FlowActivePowerSlackLowerBound`](@ref):
    
      + Bounds: [0.0, ]
      + Default proportional cost: 2e5
      + Symbol: ``f^\text{sl,lo}``

**Static Parameters**

  - ``R^\text{max}`` = `PowerSystems.get_rating(branch)`

**Objective:**

Add a large proportional cost to the objective function if rate constraint slack variables are used ``+ (f^\text{sl,up} + f^\text{sl,lo}) \cdot 2 \cdot 10^5``

**Expressions:**

No expressions are used.

**Constraints:**

For each branch ``b \in \{1,\dots, B\}`` (in a system with ``N`` buses) the constraints are given by:

```math
\begin{aligned}
&  f_t = \sum_{i=1}^N \text{PTDF}_{i,b} \cdot \text{Bal}_{i,t}, \quad \forall t \in \{1,\dots, T\}\\
&  f_t - f_t^\text{sl,up} \le R^\text{max},\quad \forall t \in \{1,\dots, T\} \\
&  f_t + f_t^\text{sl,lo} \ge -R^\text{max},\quad \forall t \in \{1,\dots, T\} 
\end{aligned}
```

on which ``\text{PTDF}`` is the ``N \times B`` system Power Transfer Distribution Factors (PTDF) matrix, and ``\text{Bal}_{i,t}`` is the active power bus balance expression (i.e. ``\text{Generation}_{i,t} - \text{Demand}_{i,t}``) at bus ``i`` at time-step ``t``.

* * *

## `StaticBranchBounds`

Formulation valid for `PTDFPowerModel` Network model

```@docs
StaticBranchBounds
```

**Variables:**

  - [`FlowActivePowerVariable`](@ref):
    
      + Bounds: ``\left[-R^\text{max},R^\text{max}\right]``
      + Symbol: ``f``

**Static Parameters**

  - ``R^\text{max}`` = `PowerSystems.get_rating(branch)`

**Objective:**

No cost is added to the objective function.

**Expressions:**

No expressions are used.

**Constraints:**

For each branch ``b \in \{1,\dots, B\}`` (in a system with ``N`` buses) the constraints are given by:

```math
\begin{aligned}
&  f_t = \sum_{i=1}^N \text{PTDF}_{i,b} \cdot \text{Bal}_{i,t}, \quad \forall t \in \{1,\dots, T\}
\end{aligned}
```

on which ``\text{PTDF}`` is the ``N \times B`` system Power Transfer Distribution Factors (PTDF) matrix, and ``\text{Bal}_{i,t}`` is the active power bus balance expression (i.e. ``\text{Generation}_{i,t} - \text{Demand}_{i,t}``) at bus ``i`` at time-step ``t``.

* * *

## `StaticBranchUnbounded`

Formulation valid for `PTDFPowerModel` Network model

```@docs
StaticBranchUnbounded
```

  - [`FlowActivePowerVariable`](@ref):
    
      + Bounds: ``(-\infty,\infty)``
      + Symbol: ``f``

**Objective:**

No cost is added to the objective function.

**Expressions:**

No expressions are used.

**Constraints:**

For each branch ``b \in \{1,\dots, B\}`` (in a system with ``N`` buses) the constraints are given by:

```math
\begin{aligned}
&  f_t = \sum_{i=1}^N \text{PTDF}_{i,b} \cdot \text{Bal}_{i,t}, \quad \forall t \in \{1,\dots, T\}
\end{aligned}
```

on which ``\text{PTDF}`` is the ``N \times B`` system Power Transfer Distribution Factors (PTDF) matrix, and ``\text{Bal}_{i,t}`` is the active power bus balance expression (i.e. ``\text{Generation}_{i,t} - \text{Demand}_{i,t}``) at bus ``i`` at time-step ``t``.

* * *

## `HVDCTwoTerminalUnbounded`

Formulation valid for `PTDFPowerModel` Network model

```@docs
HVDCTwoTerminalUnbounded
```

This model assumes that it can transfer power from two AC buses without losses and no limits.

**Variables:**

  - [`FlowActivePowerVariable`](@ref):
    
      + Bounds: ``\left(-\infty,\infty\right)``
      + Symbol: ``f``

**Objective:**

No cost is added to the objective function.

**Expressions:**

The variable `FlowActivePowerVariable` ``f`` is added to the nodal balance expression `ActivePowerBalance`, by adding the flow ``f`` in the receiving bus and subtracting it from the sending bus. This is used then to compute the AC flows using the PTDF equation.

**Constraints:**

No constraints are added.

* * *

## `HVDCTwoTerminalLossless`

Formulation valid for `PTDFPowerModel` Network model

```@docs
HVDCTwoTerminalLossless
```

This model assumes that it can transfer power from two AC buses without losses.

**Variables:**

  - [`FlowActivePowerVariable`](@ref):
    
      + Bounds: ``\left(-\infty,\infty\right)``
      + Symbol: ``f``

**Static Parameters**

  - ``R^\text{from,min}`` = `PowerSystems.get_active_power_limits_from(branch).min`
  - ``R^\text{from,max}`` = `PowerSystems.get_active_power_limits_from(branch).max`
  - ``R^\text{to,min}`` = `PowerSystems.get_active_power_limits_to(branch).min`
  - ``R^\text{to,max}`` = `PowerSystems.get_active_power_limits_to(branch).max`

**Objective:**

No cost is added to the objective function.

**Expressions:**

The variable `FlowActivePowerVariable` ``f`` is added to the nodal balance expression `ActivePowerBalance`, by adding the flow ``f`` in the receiving bus and subtracting it from the sending bus. This is used then to compute the AC flows using the PTDF equation.

**Constraints:**

```math
\begin{align*}
&  R^\text{min} \le f_t  \le R^\text{max},\quad \forall t \in \{1,\dots, T\} \\
\end{align*}
```

where:

```math
\begin{align*}
&  R^\text{min} = \begin{cases}
			\min\left(R^\text{from,min}, R^\text{to,min}\right), & \text{if } R^\text{from,min} \ge 0 \text{ and } R^\text{to,min} \ge 0 \\
      \max\left(R^\text{from,min}, R^\text{to,min}\right), & \text{if } R^\text{from,min} \le 0 \text{ and } R^\text{to,min} \le 0 \\
      R^\text{from,min},& \text{if } R^\text{from,min} \le 0 \text{ and } R^\text{to,min} \ge 0 \\
      R^\text{to,min},& \text{if } R^\text{from,min} \ge 0 \text{ and } R^\text{to,min} \le 0
		 \end{cases}
\end{align*}
```

and

```math
\begin{align*}
&  R^\text{max} = \begin{cases}
			\min\left(R^\text{from,max}, R^\text{to,max}\right), & \text{if } R^\text{from,max} \ge 0 \text{ and } R^\text{to,max} \ge 0 \\
      \max\left(R^\text{from,max}, R^\text{to,max}\right), & \text{if } R^\text{from,max} \le 0 \text{ and } R^\text{to,max} \le 0 \\
      R^\text{from,max},& \text{if } R^\text{from,max} \le 0 \text{ and } R^\text{to,max} \ge 0 \\
      R^\text{to,max},& \text{if } R^\text{from,max} \ge 0 \text{ and } R^\text{to,max} \le 0
		 \end{cases}
\end{align*}
```

* * *

## `HVDCTwoTerminalDispatch`

Formulation valid for `PTDFPowerModel` Network model

```@docs
HVDCTwoTerminalDispatch
```

**Variables**

  - [`FlowActivePowerToFromVariable`](@ref):
    
      + Symbol: ``f^\text{to-from}``

  - [`FlowActivePowerFromToVariable`](@ref):
    
      + Symbol: ``f^\text{from-to}``
  - [`HVDCLosses`](@ref):
    
      + Symbol: ``\ell``
  - [`HVDCFlowDirectionVariable`](@ref)
    
      + Bounds: ``\{0,1\}``
      + Symbol: ``u^\text{dir}``

**Static Parameters**

  - ``R^\text{from,min}`` = `PowerSystems.get_active_power_limits_from(branch).min`
  - ``R^\text{from,max}`` = `PowerSystems.get_active_power_limits_from(branch).max`
  - ``R^\text{to,min}`` = `PowerSystems.get_active_power_limits_to(branch).min`
  - ``R^\text{to,max}`` = `PowerSystems.get_active_power_limits_to(branch).max`
  - ``L_0`` = `PowerSystems.get_loss(branch).l0`
  - ``L_1`` = `PowerSystems.get_loss(branch).l1`

**Objective:**

No cost is added to the objective function.

**Expressions:**

Each `FlowActivePowerToFromVariable` ``f^\text{to-from}`` and `FlowActivePowerFromToVariable` ``f^\text{from-to}``  is added to the nodal balance expression `ActivePowerBalance`, by adding the respective flow in the receiving bus and subtracting it from the sending bus. That is,  ``f^\text{to-from}`` adds the flow to the `from` bus, and subtracts the flow from the `to` bus, while ``f^\text{from-to}`` adds the flow to the `to` bus, and subtracts the flow from the `from` bus  This is used then to compute the AC flows using the PTDF equation.

In addition, the `HVDCLosses` are subtracted to the `from` bus in the `ActivePowerBalance` expression.

**Constraints:**

```math
\begin{align*}
&  R^\text{from,min} \le f_t^\text{from-to}  \le R^\text{from,max}, \forall t \in \{1,\dots, T\} \\
&  R^\text{to,min} \le f_t^\text{to-from}  \le R^\text{to,max},\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{to-from} - f_t^\text{from-to} \le L_1 \cdot f_t^\text{to-from} - L_0,\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{from-to} - f_t^\text{to-from} \ge L_1 \cdot f_t^\text{from-to} + L_0,\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{from-to} - f_t^\text{to-from} \ge - M^\text{big} (1 - u^\text{dir}_t),\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{to-from} - f_t^\text{from-to} \ge - M^\text{big} u^\text{dir}_t,\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{to-from} - f_t^\text{from-to} \le \ell_t,\quad \forall t \in \{1,\dots, T\} \\
& f_t^\text{from-to} - f_t^\text{to-from} \le \ell_t,\quad \forall t \in \{1,\dots, T\} 
\end{align*}
```

* * *

## `HVDCTwoTerminalPiecewiseLoss`

Formulation valid for `PTDFPowerModel` Network model

```@docs
HVDCTwoTerminalPiecewiseLoss
```

This formulation creates uses ``S`` segments to define different loss factors (proportional to power flowing through the branch) at pre-determined breakpoints.

**Variables**

  - [`HVDCActivePowerReceivedFromVariable`](@ref):
    
      + Bounds: ``[R^\text{from,min}, R^\text{from,max}]``
      + Symbol: ``f^\text{from}``

  - [`HVDCActivePowerReceivedToVariable`](@ref):
    
      + Bounds: ``[R^\text{to,min}, R^\text{to,max}]``
      + Symbol: ``f^\text{to}``
  - [`HVDCPiecewiseLossVariable`](@ref):
    
      + Symbol: ``w``
  - [`HVDCPiecewiseBinaryLossVariable`](@ref):
    
      + Bounds: ``\{0,1\}``
      + Symbol: ``z``

**Static Parameters**

  - ``R^\text{from,min}`` = `PowerSystems.get_active_power_limits_from(branch).min`
  - ``R^\text{from,max}`` = `PowerSystems.get_active_power_limits_from(branch).max`
  - ``R^\text{to,min}`` = `PowerSystems.get_active_power_limits_to(branch).min`
  - ``R^\text{to,max}`` = `PowerSystems.get_active_power_limits_to(branch).max`
  - ``loss`` = `PowerSystems.get_loss(branch)`

The `loss` term is a `PowerSystems.PiecewiseIncrementalCurve` that has `S+1` power breakpoints and `S` loss factors for each range. The `PowerSystems.PiecewiseIncrementalCurve` must be defined in system per unit, that is, the power breakpoints normalized by the system base (not in MW), and the `slopes` as a factor of system base power value. Alternatively, a `PowerSystems.LinearCurve` as a way of using a single loss factor.

**Expressions:**

Each `HVDCActivePowerReceivedFromVariable` ``f^\text{from}`` and `HVDCActivePowerReceivedToVariable` ``f^\text{to}``  is added to the nodal balance expression `ActivePowerBalance`, by subtracting the received flow to the respective  bus. That is,  ``f^\text{from}`` subtract the flow to the `from` bus, while ``f^\text{to}`` subtract the flow to the `to` bus.

**Constraints:**

Define ``P_{send,s}`` as the HVDC sending end (in pu) for segment `s` and ``lossfactor_s`` as the HVDC proportional loss factor of segment `s`, then the additional auxiliary parameters ``x,y`` are used for a bi-directional two terminal HVDC from bus `i` to bus `j` with each bus can be either sending or receiving end, the MW of the two ends can have the following corresponding segments:

```math
\begin{align*}
    x_1 = -P_{send,S}-P_{send,0}, &&  y_1= P_{send,S}(1-lossfactor_S) && \\
    \text{...} &&\\
     x_S= -P_{send,1}-P_{send,0}, &&  y_S= P_{send,1}(1-lossfactor_1)  &&\\
     x_{S+1}=-P_{send,0}, &&  y_{S+1}=0  &&\\
     x_{S+2}=0,           &&  y_{S+2}=-P_{send,0}  &&\\
     x_{S+3}= P_{send,1}(1-lossfactor_1), &&  y_{S+3}= -P_{send,1}-P_{send,0}  &&\\
    \text{...} &&\\
     x_{2S+2}= P_{send,S}(1-lossfactor_S), && y_{2S+2} = -P_{send,S}-P_{send,0}  &&
\end{align*}
```

Define ``n=2S+2``, then the following constraints are used to specify the segment:

```math
\begin{align*}
    z_1+z_2+...+z_{n-1} = 1    &&\\
    0 \le w_i \le z_i  \text {      for } i=1, ..., n-1 &&
\end{align*}
```

with ``w_{S+1} = 0`` to prevent a solution in the deadband. Then the receiving flows can be computed as:

```math
\begin{align*}
    f^{from}=x_1z_1+(x_2-x_1)w_1+ x_2z_2+(x_3-x_2)w_2 + ... +x_{n-1}z_{n-1}+ (x_n-x_{n-1})w_{n-1}  &&\\
    f^{to}=y_1z_1+(y_2-y_1)w_1+ y_2z_2+(y_3-y_2)w_2 + ... +y_{n-1}z_{n-1}+ (y_n-y_{n-1})w_{n-1}  &&
\end{align*}
```

* * *

## `HVDCTwoTerminalVSCLoss`

Formulation valid for `PTDFPowerModel` Network model

```@docs
HVDCTwoTerminalVSCLoss
```

**Variables**

  - [`HVDCActiveDCPowerSentFromVariable`](@ref):
    
      + Bounds: ``[P^\text{from,min}, P^\text{from,max}]``
      + Symbol: ``p_c^\text{from}``

  - [`HVDCActiveDCPowerSentToVariable`](@ref):
    
      + Bounds: ``[P^\text{to,min}, P^\text{to,max}]``
      + Symbol: ``p_c^\text{to}``
  - [`ConverterPowerDirection`](@ref):
    
      + Bounds: ``\{0,1\}``
      + Symbol: ``\kappa^p``
  - [`DCVoltageFrom`](@ref):
    
      + Bounds: ``[V^\text{min}, V^\text{max}]``
      + Symbol: ``v_{dc}^\text{from}``
  - [`DCVoltageTo`](@ref):
    
      + Bounds: ``[V^\text{min}, V^\text{max}]``
      + Symbol: ``v_{dc}^\text{to}``
  - [`SquaredDCVoltageFrom`](@ref):
    
      + Bounds: ``[(V^\text{min})^2, (V^\text{max})^2]``
      + Symbol: ``v_{dc}^\text{sq,from}``
  - [`SquaredDCVoltageTo`](@ref):
    
      + Bounds: ``[(V^\text{min})^2, (V^\text{max})^2]``
      + Symbol: ``v_{dc}^\text{sq,to}``
  - [`ConverterCurrent`](@ref):
    
      + Bounds: ``[-I^\text{max}, I^\text{max}]``
      + Symbol: ``i``
  - [`SquaredConverterCurrent`](@ref):
    
      + Bounds: ``[0, (I^\text{max})^2]``
      + Symbol: ``i^\text{sq}``
  - [`ConverterPositiveCurrent`](@ref):
    
      + Bounds: ``[0, I^\text{max}]``
      + Symbol: ``i^+``
  - [`ConverterNegativeCurrent`](@ref):
    
      + Bounds: ``[0, I^\text{max}]``
      + Symbol: ``i^-``
  - [`ConverterCurrentDirection`](@ref):
    
      + Bounds: ``\{0,1\}``
      + Symbol: ``\kappa^i``
  - [`HVDCLosses`](@ref):
    
      + Symbol: ``p_c^{loss}``
  - [`AuxBilinearConverterVariableFrom`](@ref):
    
      + Bounds: ``[-I^\text{max}V^\text{min}, I^\text{max}V^\text{max}]``
      + Symbol: ``γ^\text{from}``
  - [`AuxBilinearConverterVariableTo`](@ref):
    
      + Bounds: ``[-I^\text{max}V^\text{min}, I^\text{max}V^\text{max}]``
      + Symbol: ``γ^\text{to}``
  - [`AuxBilinearSquaredConverterVariableFrom`](@ref):
    
      + Bounds: ``[0, (I^\text{max})^2(V^\text{max})^2]``
      + Symbol: ``γ^\text{sq,from}``
  - [`AuxBilinearSquaredConverterVariableFrom`](@ref):
    
      + Bounds: ``[(V^\text{min})^2, (V^\text{max})^2]``
      + Symbol: ``v_{dc}^\text{sq,to}``

And the additional continuous interpolation variables for voltage, current and bilinear auxiliary variable, denoted as ``\delta^v, \delta^i, \delta^\gamma``, and additional binary interpolation variables for voltage current and bilinear auxiliary variable, denoted as ``z^v, z^i, z^\gamma`` .

**Static Parameters**

  - ``P^\text{from,min}`` = `PowerSystems.get_active_power_limits_from(branch).min`
  - ``P^\text{from,max}`` = `PowerSystems.get_active_power_limits_from(branch).max`
  - ``P^\text{to,min}`` = `PowerSystems.get_active_power_limits_to(branch).min`
  - ``P^\text{to,max}`` = `PowerSystems.get_active_power_limits_to(branch).max`
  - ``V^\text{min}`` = `PowerSystems.get_voltage_limits(branch).min`
  - ``V^\text{max}`` = `PowerSystems.get_voltage_limits(branch).max`
  - ``I^{max}`` = `PowerSystems.max_dc_current(branch)`
  - ``loss`` = `PowerSystems.get_loss(branch)`
  - ``g`` = `PowerSystems.get_g(branch)`

The `loss` term is a `PowerSystems.QuadraticCurve` that has the quadratic term ``a``, proportional term ``b`` and constant term ``c``. In addition, the interpolation is done by specifying the number of segments for voltage, current and bilinear term independently as attributes of the `DeviceModel`. The breakpoints are done by evenly splitting the available range for each variable. By default 3 voltage segments, 6 current segments and 10 bilinear segments are used.

**Expressions:**

Each `HVDCActiveDCPowerSentFromVariable` ``f^\text{from}`` and `HVDCActiveDCPowerSentToVariable` ``p^\text{to}``  is added to the nodal balance expression `ActivePowerBalance`, by subtracting the received flow to the respective  bus. That is,  ``p^\text{from}`` subtract the flow to the `from` bus, while ``p^\text{to}`` subtract the flow to the `to` bus. In addition, the losses are ``p^{loss}`` are subtracted to both sending and receiving bus, as it is assumed that converter losses occurs in both ends.

**Constraints:**

```math
\begin{align*}
\gamma_{c, t}^\text{from} &= v_{c, t}^\text{from} + i_{c, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    p_{c, t}^\text{from} &= \frac{1}{2}\left(\gamma^\text{sq,from}_{c, t} - v^\text{sq,from}_{c, t} - i^\text{sq}_{c, t} \right) & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    \gamma_{c, t}^\text{to} &= v_{c, t}^\text{to} - i_{c, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    p_{c, t}^\text{to} &= \frac{1}{2}\left(\gamma^\text{sq,to}_{c, t} - v^\text{sq,to}_{c, t} - i^\text{sq}_{c, t} \right) & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}
\end{align*}
```

```math
\begin{align*}
    (-I^{max}_c) \left(1 - \kappa_{c, t}\right) &\le i_{c, t} \le I^{max}_c \kappa_{c, t}\\
    P^\text{min,from}_c \left(1 - \kappa_{c, t} \right) &\le p_{b, t} \le P^\text{max,from}_c \kappa_{c, t}\\
    P^\text{min,to}_c  \kappa_{c, t}  &\le p_{b, t} \le P^\text{max,to}_c (1 - \kappa_{c, t})
\end{align*}
```

```math
\begin{align*}
    i_{c, t} &= \frac{1}{r_\ell} (v_{c,t}^\text{from} - v_{c,t}^\text{to}) & \forall \ell \in \mathcal{L}, \ \forall t \in \mathcal{T}
\end{align*}
```

```math
\begin{align*}
    p_{c, t}^\text{from} &\ge V^{min} i_{c, t} + v_{c, t}^\text{from} (-I^{max}_{c}) - (-I^{max}_{c}V^{min})& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    p_{c, t}^\text{from} &\ge V^{max} i_{c, t} + v_{c, t}^\text{from}(I^{max}_{c}) - (I^{max}_{c}V^{max})& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    p_{c, t}^\text{from} &\le V^{max} i_{c, t} + v_{c, t}^\text{from}(-I^{max}_{c}) - (-I^{max}_{c}V^{max}) & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    p_{c, t}^\text{from} &\leq V^{min} i_{c, t} + v_{c, t}^\text{from}(I^{max}_{c}) - (I^{max}_{c}V^{min})& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} \\
    p_{c, t}^\text{to} &\ge V^{min} (-i_{c, t}) + v_{c, t}^\text{to} (-I^{max}_{c}) - (-I^{max}_{c}V^{min})& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    p_{c, t}^\text{to} &\ge V^{max} (-i_{c, t}) + v_{c, t}^\text{to}(I^{max}_{c}) - (I^{max}_{c}V^{max})& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    p_{c, t}^\text{to} &\le V^{max} (-i_{c, t}) + v_{c, t}^\text{to}(-I^{max}_{c}) - (-I^{max}_{c}V^{max}) & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    p_{c, t}^\text{to} &\leq V^{min} (-i_{c, t}) + v_{c, t}^\text{to}(I^{max}_{c}) - (I^{max}_{c}V^{min})& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}
\end{align*}
```

```math
\begin{align*}
    v_{c, t}^\text{from} &= V^{min} + \sum_{k \in \mathcal{K}_v} \left(V_{c, k} - V_{c, {k-1}}\right) \delta^\text{v,from}_{c, k, t}\\
    v^\text{sq,from}_{c, t} &= {V^{min}}^2 + \sum_{k \in \mathcal{K}_\gamma} \left(V^{sq}_{c, k} - V^{sq}_{c, {k-1}}\right) \delta^\text{v,from}_{c, k, t}& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    0 &\le \delta^\text{v,from}_{c, k, t} \le 1 & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^\text{v,from}_{k, c, t} &\ge \delta^\text{v,from}_{c, {k + 1}, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^\text{v,from}_{k, c, t} &\le \delta^\text{v,from}_{c, k, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^\text{v,from}_{k, c, t} &\in \left\{ 0, 1 \right\} & \forall k \in \mathcal{K}^v, \ \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} \\
    v_{c, t}^\text{to} &= V^{min} + \sum_{k \in \mathcal{K}_\gamma} \left(V_{c, k} - V_{c, {k-1}}\right) \delta^\text{v,to}_{c, k, t}\\
    v^\text{sq,to}_{c, t} &= {V^{min}}^2 + \sum_{k \in \mathcal{K}_v} \left(V^{sq}_{c, k} - V^{sq}_{c, {k-1}}\right) \delta^\text{v,to}_{c, k, t}& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    0 &\le \delta^\text{v,to}_{c, k, t} \le 1 & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^\text{v,to}_{k, c, t} &\ge \delta^\text{v,to}_{c, {k + 1}, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^\text{v,to}_{k, c, t} &\le \delta^\text{v,to}_{c, k, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^\text{v,to}_{k, c, t} &\in \left\{ 0, 1 \right\} & \forall k \in \mathcal{K}_v, \ \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}
\end{align*}
```

```math
\begin{align*}
    i_{c, t} &= I^{min} + \sum_{k \in \mathcal{K}_i} \left(I_{c, k} - I_{c, {k-1}}\right) \delta^\text{i,from}_{c, k, t}\\
    i^\text{sq,from}_{c, t} &= {I^{min}}^2 + \sum_{k \in \mathcal{K}_i} \left(I^{sq}_{c, k} - I^{sq}_{c, {k-1}}\right) \delta^\text{i,from}_{c, k, t}& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    0 &\le \delta^\text{i,from}_{c, k, t} \le 1 & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^\text{i}_{k, c, t} &\ge \delta^\text{i}_{c, {k + 1}, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^\text{i}_{k, c, t} &\le \delta^\text{i}_{c, k, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^\text{i}_{k, c, t} &\in \left\{ 0, 1 \right\} & \forall k \in \mathcal{K}_i, \ \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} 
\end{align*}
```

```math
\begin{align*}
    \gamma_{c, t}^\text{from} &= \Gamma^\text{min} + \sum_{k \in \mathcal{K}_\gamma} \left(\Gamma_{c, k} - \Gamma_{c, {k-1}}\right) \delta^{\gamma\text{,from}}_{c, k, t}\\  
    \gamma^\text{sq,from}_{c, t} &= {\Gamma^\text{min}}^2 + \sum_{k \in \mathcal{K}_v} \left(\Gamma^{sq}_{c, k} - \Gamma^{sq}_{c, {k-1}}\right) \delta^{\gamma\text{,from}}_{c, k, t}& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    0 &\le \delta^{\gamma\text{,from}}_{c, k, t} \le 1 & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^{\gamma\text{,from}}_{k, c, t} &\ge \delta^{\gamma\text{,from}}_{c, {k + 1}, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^{\gamma\text{,from}}_{k, c, t} &\le \delta^{\gamma\text{,from}}_{c, k, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^{\gamma\text{,from}}_{k, c, t} &\in \left\{ 0, 1 \right\} & \forall k \in \mathcal{K}_\gamma, \ \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} \\
    \gamma_{c, t}^\text{to} &= \Gamma^\text{min} + \sum_{k \in \mathcal{K}_\gamma} \left(\Gamma_{c, k} - \Gamma_{c, {k-1}}\right) \delta^{\gamma\text{,to}}_{c, k, t}\\  
    \gamma^\text{sq,to}_{c, t} &= {\Gamma^\text{min}}^2 + \sum_{k \in \mathcal{K}_v} \left(\Gamma^{sq}_{c, k} - \Gamma^{sq}_{c, {k-1}}\right) \delta^{\gamma\text{,to}}_{c, k, t}& \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    0 &\le \delta^{\gamma\text{,to}}_{c, k, t} \le 1 & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^{\gamma\text{,to}}_{k, c, t} &\ge \delta^{\gamma\text{,to}}_{c, {k + 1}, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^{\gamma\text{,to}}_{k, c, t} &\le \delta^{\gamma\text{,to}}_{c, k, t} & \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\
    z^{\gamma\text{,to}}_{k, c, t} &\in \left\{ 0, 1 \right\} & \forall k \in \mathcal{K}_\gamma, \ \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} 
\end{align*}
```

```math
\begin{align*}
    i_{c,t} &= i_{c,t}^+ - i_{c,t}^-, &  \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\ 
    i_{c,t}^+ &\le I_c^{max} \nu_{c,t} , &  \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}\\ 
    i_{c,t}^- &\le  I_c^{max}(1 - \nu_{c,t}), &  \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}
\end{align*}
```

```math
\begin{align*}
    p_{c,t}^\text{loss} = a_c + b_c (i_{c,t}^+ + i_{c,t}^-) + c_c i_{c,t}^\text{sq}, &  \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}
\end{align*}
```

* * *

## `HVDCTwoTerminalVSCLossBilinear`

Formulation valid for `ACPowerModel` Network model

```@docs
HVDCTwoTerminalVSCLossBilinear
```

**Variables**

  - [`HVDCActiveDCPowerSentFromVariable`](@ref):
    
      + Bounds: ``[P^\text{from,min}, P^\text{from,max}]``
      + Symbol: ``p_c^\text{from}``

  - [`HVDCActiveDCPowerSentToVariable`](@ref):
    
      + Bounds: ``[P^\text{to,min}, P^\text{to,max}]``
      + Symbol: ``p_c^\text{to}``
  - [`HVDCReactivePowerSentFromVariable`](@ref):
    
      + Bounds: ``[Q^\text{from,min}, Q^\text{from,max}]``
      + Symbol: ``q_c^\text{from}``
  - [`HVDCReactivePowerSentToVariable`](@ref):
    
      + Bounds: ``[Q^\text{to,min}, Q^\text{to,max}]``
      + Symbol: ``q_c^\text{to}``
  - [`DCVoltageFrom`](@ref):
    
      + Bounds: ``[V^\text{min}, V^\text{max}]``
      + Symbol: ``v_{dc}^\text{from}``
  - [`DCVoltageTo`](@ref):
    
      + Bounds: ``[V^\text{min}, V^\text{max}]``
      + Symbol: ``v_{dc}^\text{to}``
  - [`ConverterCurrent`](@ref):
    
      + Bounds: ``[-I^\text{max}, I^\text{max}]``
      + Symbol: ``i``
  - [`HVDCLosses`](@ref):
    
      + Symbol: ``p_c^{loss}``

**Static Parameters**

  - ``P^\text{from,min}`` = `PowerSystems.get_active_power_limits_from(branch).min`
  - ``P^\text{from,max}`` = `PowerSystems.get_active_power_limits_from(branch).max`
  - ``P^\text{to,min}`` = `PowerSystems.get_active_power_limits_to(branch).min`
  - ``P^\text{to,max}`` = `PowerSystems.get_active_power_limits_to(branch).max`
  - ``Q^\text{from,min}`` = `PowerSystems.get_reactive_power_limits_from(branch).min`
  - ``Q^\text{from,max}`` = `PowerSystems.get_reactive_power_limits_from(branch).max`
  - ``Q^\text{to,min}`` = `PowerSystems.get_reactive_power_limits_to(branch).min`
  - ``Q^\text{to,max}`` = `PowerSystems.get_reactive_power_limits_to(branch).max`
  - ``V^\text{min}`` = `PowerSystems.get_voltage_limits(branch).min`
  - ``V^\text{max}`` = `PowerSystems.get_voltage_limits(branch).max`
  - ``I^{max}`` = `PowerSystems.max_dc_current(branch)`
  - ``loss`` = `PowerSystems.get_loss(branch)`
  - ``g`` = `PowerSystems.get_g(branch)`

The `loss` term is a `PowerSystems.QuadraticCurve` that has the quadratic term ``a``, proportional term ``b`` and constant term ``c``.

**Expressions:**

Each `HVDCActiveDCPowerSentFromVariable` ``p^\text{from}`` and `HVDCActiveDCPowerSentToVariable` ``p^\text{to}``  is added to the nodal balance expression `ActivePowerBalance`, by subtracting the received flow to the respective  bus. That is,  ``p^\text{from}`` subtract the flow to the `from` bus, while ``p^\text{to}`` subtract the flow to the `to` bus. Similarly for the reactive power variables. In addition, the losses are ``p^{loss}`` are subtracted to both sending and receiving bus, as it is assumed that converter losses occurs in both ends.

**Constraints:**

```math
\begin{align*}
 p_{c,t}^{from} = v_{c,t}^{from} \cdot i_{c,t}, & \  \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} \\
 p_{c,t}^{to} = v_{c,t}^{from} \cdot (-i_{c,t}), & \  \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T}  \\
 i_{c, t} = \frac{1}{r_\ell} (v_{c,t}^\text{from} - v_{c,t}^\text{to}), &  \ \forall \ell \in \mathcal{L}_c, \ \forall t \in \mathcal{T} \\
 p_{c,t}^\text{loss} = a_c + b_c |i_{c,t}| + c_c i_{c,t}^2, & \  \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} \\
 (p_{c,t}^{from})^2 + (q_{c,t}^{from})^2 \le \text{rating}^2, & \ \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} \\
 (p_{c,t}^{to})^2 + (q_{c,t}^{to})^2 \le \text{rating}^2, & \  \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} 
\end{align*}
```

* * *

## `HVDCTwoTerminalVSCLossQuadratic`

Formulation valid for `ACPowerModel` Network model

```@docs
HVDCTwoTerminalVSCLossQuadratic
```

**Variables**

  - [`HVDCActiveDCPowerSentFromVariable`](@ref):
    
      + Bounds: ``[P^\text{from,min}, P^\text{from,max}]``
      + Symbol: ``p_c^\text{from}``

  - [`HVDCActiveDCPowerSentToVariable`](@ref):
    
      + Bounds: ``[P^\text{to,min}, P^\text{to,max}]``
      + Symbol: ``p_c^\text{to}``
  - [`HVDCReactivePowerSentFromVariable`](@ref):
    
      + Bounds: ``[Q^\text{from,min}, Q^\text{from,max}]``
      + Symbol: ``q_c^\text{from}``
  - [`HVDCReactivePowerSentToVariable`](@ref):
    
      + Bounds: ``[Q^\text{to,min}, Q^\text{to,max}]``
      + Symbol: ``q_c^\text{to}``
  - [`HVDCLosses`](@ref):
    
      + Symbol: ``p_c^{loss}``

**Static Parameters**

  - ``P^\text{from,min}`` = `PowerSystems.get_active_power_limits_from(branch).min`
  - ``P^\text{from,max}`` = `PowerSystems.get_active_power_limits_from(branch).max`
  - ``P^\text{to,min}`` = `PowerSystems.get_active_power_limits_to(branch).min`
  - ``P^\text{to,max}`` = `PowerSystems.get_active_power_limits_to(branch).max`
  - ``Q^\text{from,min}`` = `PowerSystems.get_reactive_power_limits_from(branch).min`
  - ``Q^\text{from,max}`` = `PowerSystems.get_reactive_power_limits_from(branch).max`
  - ``Q^\text{to,min}`` = `PowerSystems.get_reactive_power_limits_to(branch).min`
  - ``Q^\text{to,max}`` = `PowerSystems.get_reactive_power_limits_to(branch).max`
  - ``loss`` = `PowerSystems.get_loss(branch)`

The `loss` term is a `PowerSystems.QuadraticCurve` that has the quadratic term ``a``, proportional term ``b`` and constant term ``c``.

**Expressions:**

Each `HVDCActiveDCPowerSentFromVariable` ``p^\text{from}`` and `HVDCActiveDCPowerSentToVariable` ``p^\text{to}``  is added to the nodal balance expression `ActivePowerBalance`, by subtracting the received flow to the respective  bus. That is,  ``p^\text{from}`` subtract the flow to the `from` bus, while ``p^\text{to}`` subtract the flow to the `to` bus. Similarly for the reactive power variables.

**Constraints:**

The quadratic model only approximates losses in the `from` side of the line, proportional to the `from` power sent or received.

```math
\begin{align*}
 p_{c,t}^{from} - p_{c,t}^{loss} = - p_{c,t}^{to}, & \ \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} \\
 p_{c,t}^\text{loss} = a_c + b_c |p_{c,t}^{from}| + c_c (p_{c,t}^{from})^2 &  \forall c \in \mathcal{C}, & \ \forall t \in \mathcal{T} \\
 (p_{c,t}^{from})^2 + (q_{c,t}^{from})^2 \le \text{rating}^2, & \   \forall c \in \mathcal{C}, & \ \forall t \in \mathcal{T} \\
 (p_{c,t}^{to})^2 + (q_{c,t}^{to})^2 \le \text{rating}^2, & \  \forall c \in \mathcal{C}, \ \forall t \in \mathcal{T} 
\end{align*}
```

* * *

## `PhaseAngleControl`

Formulation valid for `PTDFPowerModel` Network model

```@docs
PhaseAngleControl
```

**Variables:**

  - [`FlowActivePowerVariable`](@ref):
    
      + Bounds: ``(-\infty,\infty)``
      + Symbol: ``f``

  - [`PhaseShifterAngle`](@ref):
    
      + Symbol: ``\theta^\text{shift}``

**Static Parameters**

  - ``R^\text{max}`` = `PowerSystems.get_rating(branch)`
  - ``\Theta^\text{min}`` = `PowerSystems.get_phase_angle_limits(branch).min`
  - ``\Theta^\text{max}`` = `PowerSystems.get_phase_angle_limits(branch).max`
  - ``X`` = `PowerSystems.get_x(branch)` (series reactance)

**Objective:**

No changes to objective function

**Expressions:**

Adds to the `ActivePowerBalance` expression the term ``-\theta^\text{shift} /X`` to the `from` bus and ``+\theta^\text{shift} /X`` to the `to` bus, that the `PhaseShiftingTransformer` is connected.

**Constraints:**

For each branch ``b \in \{1,\dots, B\}`` (in a system with ``N`` buses) the constraints are given by:

```math
\begin{aligned}
&  f_t = \sum_{i=1}^N \text{PTDF}_{i,b} \cdot \text{Bal}_{i,t} + \frac{\theta^\text{shift}_t}{X}, \quad \forall t \in \{1,\dots, T\}\\
&  -R^\text{max} \le f_t  \le R^\text{max},\quad \forall t \in \{1,\dots, T\} 
\end{aligned}
```

on which ``\text{PTDF}`` is the ``N \times B`` system Power Transfer Distribution Factors (PTDF) matrix, and ``\text{Bal}_{i,t}`` is the active power bus balance expression (i.e. ``\text{Generation}_{i,t} - \text{Demand}_{i,t}``) at bus ``i`` at time-step ``t``.

* * *

## Valid configurations

Valid `DeviceModel`s for subtypes of `Branch` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> (x["device_type"] <: Branch) && (x["device_type"] != TModelHVDCLine), combos)
combo_table = DataFrame(
    "Valid DeviceModel" =>
        ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => [
        "[$(c["device_type"])](https://nrel-Sienna.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)"
        for c in combos
    ],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
)
mdtable(combo_table; latex = false)
```
