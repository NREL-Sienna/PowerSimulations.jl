
struct EconomicDispatchProblem <: DecisionProblem end
struct UnitCommitmentProblem <: DecisionProblem end
struct AGCReserveDeployment <: DecisionProblem end

function _default_devices_uc()
    return [
        DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment),
        DeviceModel(PSY.RenewableDispatch, RenewableFullDispatch),
        DeviceModel(PSY.RenewableFix, FixedOutput),
        DeviceModel(PSY.HydroEnergyReservoir, HydroDispatchRunOfRiver),
        DeviceModel(PSY.HydroDispatch, HydroDispatchRunOfRiver),
        DeviceModel(PSY.PowerLoad, StaticPowerLoad),
        DeviceModel(PSY.InterruptibleLoad, InterruptiblePowerLoad),
        DeviceModel(PSY.Line, StaticBranch),
        DeviceModel(PSY.Transformer2W, StaticBranch),
        DeviceModel(PSY.TapTransformer, StaticBranch),
        DeviceModel(PSY.HVDCLine, HVDCDispatch),
    ]
end

function _default_devices_dispatch()
    default = _default_devices_uc()
    default[1] = DeviceModel(PSY.ThermalStandard, ThermalDispatch)
    return default
end

function _default_services()
    return [
        ServiceModel(PSY.VariableReserve{PSY.ReserveUp}, RangeReserve),
        ServiceModel(PSY.VariableReserve{PSY.ReserveDown}, RangeReserve),
    ]
end

"""
    template_unit_commitment(; kwargs...)

Creates an `ProblemTemplate` with default DeviceModels for a Unit Commitment
problem.

# Example
```julia
template = template_unit_commitment()
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Vector{DeviceModel}` : override default `DeviceModel` settings
- `services::Vector{ServiceModel}` : override default `ServiceModel` settings
"""
function template_unit_commitment(; kwargs...)
    network = get(kwargs, :network, CopperPlatePowerModel)
    template = ProblemTemplate(network)
    for model in get(kwargs, :devices, _default_devices_uc())
        set_device_model!(template, model)
    end

    for model in get(kwargs, :services, _default_services())
        set_service_model!(template, model)
    end
    return template
end

"""
    template_economic_dispatch(; kwargs...)

Creates an `ProblemTemplate` with default DeviceModels for an Economic Dispatch
problem.

# Example
```julia
template = template_economic_dispatch()
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Vector{DeviceModel}` : override default `DeviceModel` settings
- `services::Vector{ServiceModel}` : override default `ServiceModel` settings
"""
function template_economic_dispatch(; kwargs...)
    network = get(kwargs, :network, CopperPlatePowerModel)
    template = ProblemTemplate(network)
    for model in get(kwargs, :devices, _default_devices_dispatch())
        set_device_model!(template, model)
    end

    for model in get(kwargs, :services, _default_services())
        set_service_model!(template, model)
    end

    return template
end

"""
    template_agc_reserve_deployment(; kwargs...)

Creates an `ProblemTemplate` with default DeviceModels for an AGC Reserve Deplyment Problem. This model doesn't support customization

# Example
```julia
template = agc_reserve_deployment()
```
"""
function template_agc_reserve_deployment(; kwargs...)
    if !isempty(kwargs)
        throw(ArgumentError("AGC Template doesn't currently support customization"))
    end
    template = ProblemTemplate(AreaBalancePowerModel)
    set_device_model!(template, PSY.ThermalStandard, FixedOutput)
    set_device_model!(template, PSY.RenewableDispatch, FixedOutput)
    set_device_model!(template, PSY.PowerLoad, StaticPowerLoad)
    set_device_model!(template, PSY.HydroEnergyReservoir, FixedOutput)
    set_device_model!(template, PSY.HydroDispatch, FixedOutput)
    set_device_model!(template, PSY.RenewableFix, FixedOutput)
    set_device_model!(
        template,
        DeviceModel(PSY.RegulationDevice{PSY.ThermalStandard}, DeviceLimitedRegulation),
    )
    set_device_model!(
        template,
        DeviceModel(PSY.RegulationDevice{PSY.HydroDispatch}, ReserveLimitedRegulation),
    )
    set_device_model!(
        template,
        DeviceModel(
            PSY.RegulationDevice{PSY.HydroEnergyReservoir},
            ReserveLimitedRegulation,
        ),
    )
    set_service_model!(template, ServiceModel(PSY.AGC, PIDSmoothACE))
    return template
end
