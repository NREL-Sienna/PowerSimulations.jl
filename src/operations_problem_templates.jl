struct EconomicDispatchProblem <: PowerSimulationsOperationsProblem end
struct UnitCommitmentProblem <: PowerSimulationsOperationsProblem end
struct AGCReserveDeployment <: PowerSimulationsOperationsProblem end

function _default_devices_uc()
    return Dict(
        "ThermalGenerators" => DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment),
        "RenewableEnergy" => DeviceModel(PSY.RenewableDispatch, RenewableFullDispatch),
        "DistributedRenewableEnergy" => DeviceModel(PSY.RenewableFix, FixedOutput),
        "ReservoirHydroPower" =>
            DeviceModel(PSY.HydroEnergyReservoir, HydroDispatchRunOfRiver),
        "RunofRiverHydroPower" => DeviceModel(PSY.HydroDispatch, HydroDispatchRunOfRiver),
        "Loads" => DeviceModel(PSY.PowerLoad, StaticPowerLoad),
        "InterruptibleLoads" => DeviceModel(PSY.InterruptibleLoad, InterruptiblePowerLoad),
    )
end

function _default_devices_dispatch()
    default = _default_devices_uc()
    default["ThermalGenerators"] = DeviceModel(PSY.ThermalStandard, ThermalDispatch)
    return default
end

function _default_services()
    return Dict(
        "ReserveUp" => ServiceModel(PSY.VariableReserve{PSY.ReserveUp}, RangeReserve),
        "ReserveDown" => ServiceModel(PSY.VariableReserve{PSY.ReserveDown}, RangeReserve),
    )
end

function _default_branches()
    return Dict(
        "ACLines" => DeviceModel(PSY.Line, StaticLine),
        "Transformers" => DeviceModel(PSY.Transformer2W, StaticTransformer),
        "TapTransformers" => DeviceModel(PSY.TapTransformer, StaticTransformer),
        "DCLines" => DeviceModel(PSY.HVDCLine, HVDCDispatch),
    )
end

"""
    template_unit_commitment(; kwargs...)

Creates an `OperationsProblemTemplate` with default DeviceModels for a Unit Commitment
problem.

# Example
```julia
template = template_unit_commitment()
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
"""
function template_unit_commitment(; kwargs...)
    network = get(kwargs, :network, CopperPlatePowerModel)
    template = OperationsProblemTemplate(network)
    for (k, v) in get(kwargs, :devices, _default_devices_uc())
        set_model!(template, k, v)
    end

    for (k, v) in get(kwargs, :services, _default_services())
        set_model!(template, k, v)
    end

    if network != CopperPlatePowerModel
        for (k, v) in get(kwargs, :branches, _default_branches())
            set_model!(template, k, v)
        end
    end
    return template
end

"""
    template_economic_dispatch(; kwargs...)

Creates an `OperationsProblemTemplate` with default DeviceModels for an Economic Dispatch
problem.

# Example
```julia
template = template_economic_dispatch()
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
"""
function template_economic_dispatch(; kwargs...)
    network = get(kwargs, :network, CopperPlatePowerModel)
    template = OperationsProblemTemplate(network)
    for (k, v) in get(kwargs, :devices, _default_devices_dispatch())
        set_model!(template, k, v)
    end

    for (k, v) in get(kwargs, :services, _default_services())
        set_model!(template, k, v)
    end

    if network != CopperPlatePowerModel
        for (k, v) in get(kwargs, :branches, _default_branches())
            set_model!(template, k, v)
        end
    end
    return template
end

"""
    template_agc_reserve_deployment(; kwargs...)

Creates an `OperationsProblemTemplate` with default DeviceModels for an AGC Reserve Deplyment Problem. This model doesn't support customization

# Example
```julia
template = agc_reserve_deployment()
```
"""
function template_agc_reserve_deployment(; kwargs...)
    if !isempty(kwargs)
        throw(ArgumentError("AGC Template doesn't currently support customization"))
    end
    template = OperationsProblemTemplate(AreaBalancePowerModel)
    set_model!(template, "Generators", DeviceModel(PSY.ThermalStandard, FixedOutput))
    set_model!(template, "Ren", DeviceModel(PSY.RenewableDispatch, FixedOutput))
    set_model!(template, "Loads", DeviceModel(PSY.PowerLoad, StaticPowerLoad))
    set_model!(template, "Hydro", DeviceModel(PSY.HydroEnergyReservoir, FixedOutput))
    set_model!(template, "HydroROR", DeviceModel(PSY.HydroDispatch, FixedOutput))
    set_model!(template, "RenFx", DeviceModel(PSY.RenewableFix, FixedOutput))
    set_model!(
        template,
        "Regulation_thermal",
        DeviceModel(PSY.RegulationDevi)ce{PSY.ThermalStandard},
        DeviceLimitedRegulation,
    )
    set_model!(
        template,
        "Regulation_hydro_dispatch",
        DeviceModel(PSY.RegulationDevice{PSY.HydroDispatch}, ReserveLimitedRegulation),
    )
    set_model!(
        template,
        "Regulation_hydro_reservoir",
        DeviceModel(
            PSY.RegulationDevice{PSY.HydroEnergyReservoir},
            ReserveLimitedRegulation,
        ),
    )
    set_model!(template, "AGC", ServiceModel(PSY.AGC, PIDSmoothACE))
    return template
end
