# [Operations [`ProblemTemplate`](@ref)s](@id op_problem_template)

Templates are used to specify the modeling properties of the devices and network that are going to he used to specify a problem.
A `ProblemTemplate` is just a collection of `DeviceModel`s that allows the user to specify the formulations
of each set of devices (by device type) independently so that the modeler can adjust the level of detail according to the question of interest and the available data.
For more information about valid `DeviceModel`s and their mathematical representations, check out the [Formulation Library](@ref formulation_library).

## Building a `ProblemTemplate`

You can build a `ProblemTemplate` by adding a `NetworkModel`, `DeviceModel`s, and `ServiceModels`.

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

[`template_economic_dispatch`](@ref)

```@example
using PowerSimulations #hide
template_economic_dispatch()
```

[`template_unit_commitment`](@ref)

```@example
using PowerSimulations #hide
template_unit_commitment()
```

[`template_agc_reserve_deployment`](@ref)

```@example
using PowerSimulations #hide
template_agc_reserve_deployment()
```
