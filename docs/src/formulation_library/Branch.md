# `PowerSystems.Branch` Formulations


Valid `DeviceModel`s for subtypes of `Branch` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: Branch, combos)
combo_table = DataFrame(
    "Valid DeviceModel" => ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => ["[$(c["device_type"])](https://nrel-Sienna.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)" for c in combos],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
    )
mdtable(combo_table, latex = false)
```

---

## `StaticBranch`

```@docs
StaticBranch
```

---

## `StaticBranchBounds`

```@docs
StaticBranchBounds
```

---

## `StaticBranchUnbounded`

```@docs
StaticBranchUnbounded
```

---

## `HVDCTwoTerminalLossless`

```@docs
HVDCTwoTerminalLossless
```

---

## `HVDCTwoTerminalDispatch`

```@docs
HVDCTwoTerminalDispatch
```

---

## `HVDCTwoTerminalUnbounded`

```@docs
HVDCTwoTerminalUnbounded
```
