# [Operations `ProblemTemplate`s](@id op_problem_template)

Templates are used to specify the modeling properties of the devices and network that are going to he used to specify a problem.
A `ProblemTemplate` is just a collection of [`DeviceModel`](@ref)`s that allows the user to specify the formulations of each set of devices (by device type) independently so that the modeler can adjust the level of detail according to the question of interest and the available data. For more information about valid [`DeviceModel`](@ref)s and their mathematical representations, check out the [Formulation Library](@ref formulation_intro).

## Building a `ProblemTemplate`

You can build a `ProblemTemplate` by adding a [`NetworkModel`](@ref), [`DeviceModel`](@ref)s, and [`ServiceModel`](@ref)s.

```julia
template = ProblemTemplate()
set_network_model!(template, NetworkModel(CopperPlatePowerModel))
set_device_model!(template, PowerLoad, StaticPowerLoad)
set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
set_service_model!(template, VariableReserve{ReserveUp}, RangeReserve)
```

## Default Templates

`PowerSimulations.jl` provides default templates for common operation problems. You can retrieve a default template and modify it according
to your requirements. Currently supported default templates are:

```@docs; canonical=false
template_economic_dispatch
```

```@example
using PowerSimulations #hide
template_economic_dispatch()
```

```@docs; canonical=false
template_unit_commitment
```

```@example
using PowerSimulations #hide
template_unit_commitment()
```
