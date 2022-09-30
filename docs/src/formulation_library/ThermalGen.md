# `ThermalGen` Formulations

Valid `DeviceModel`s for subtypes of `ThermalGen` include the following:

```@eval
using PowerSimulations
using PowerSystems
using DataFrames
using Latexify
combos = PowerSimulations.generate_device_formulation_combinations()
filter!(x -> x["device_type"] <: ThermalGen, combos)
combo_table = DataFrame(
    "Valid DeviceModel" => ["`DeviceModel($(c["device_type"]), $(c["formulation"]))`" for c in combos],
    "Device Type" => ["[$(c["device_type"])](https://nrel-siip.github.io/PowerSystems.jl/stable/model_library/generated_$(c["device_type"])/)" for c in combos],
    "Formulation" => ["[$(c["formulation"])](@ref)" for c in combos],
    )
mdtable(combo_table, latex = false)
```

---

## `ThermalBasicDispatch`

```@docs
ThermalBasicDispatch
```

TODO

---

## `ThermalCompactDispatch`

```@docs
ThermalCompactDispatch
```

TODO

---

## `ThermalDispatchNoMin`

```@docs
ThermalDispatchNoMin
```

TODO

---

## `ThermalStandardDispatch`

```@docs
ThermalStandardDispatch
```

TODO

---

## `ThermalBasicCompactUnitCommitment`

```@docs
ThermalBasicCompactUnitCommitment
```

TODO

---

## `ThermalCompactUnitCommitment`

```@docs
ThermalCompactUnitCommitment
```

TODO

---

## `ThermalMultiStartUnitCommitment`

```@docs
ThermalMultiStartUnitCommitment
```

TODO

---

## `ThermalBasicUnitCommitment`

```@docs
ThermalBasicUnitCommitment
```

TODO

---

## `ThermalStandardUnitCommitment`

```@docs
ThermalStandardUnitCommitment
```

TODO

---
