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
- `devices::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{Symbol, ServiceModel}` : override default `ServiceModel` settings
"""
function template_unit_commitment(; kwargs...)
    network = get(kwargs, :network, CopperPlatePowerModel)

    devices = get(
        kwargs,
        :devices,
        Dict(
            :Generators => DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment),
            :RE => DeviceModel(PSY.RenewableDispatch, RenewableFullDispatch),
            :DistRE => DeviceModel(PSY.RenewableFix, RenewableFixed),
            :Hydro => DeviceModel(PSY.HydroEnergyReservoir, HydroDispatchReservoirFlow),
            :HydroROR => DeviceModel(PSY.HydroDispatch, HydroFixed),
            :Loads => DeviceModel(PSY.PowerLoad, StaticPowerLoad),
            :ILoads => DeviceModel(PSY.InterruptibleLoad, InterruptiblePowerLoad),
        ),
    )

    branches = get(
        kwargs,
        :branches,
        Dict(
            :L => DeviceModel(PSY.Line, StaticLine),
            :T => DeviceModel(PSY.Transformer2W, StaticTransformer),
            :TT => DeviceModel(PSY.TapTransformer, StaticTransformer),
            :DC => DeviceModel(PSY.HVDCLine, HVDCDispatch),
        ),
    )

    services = get(
        kwargs,
        :services,
        Dict(
            :ReserveUp =>
                    ServiceModel(PSY.VariableReserve{PSY.ReserveUp}, RangeReserve),
            :ReserveDown =>
                    ServiceModel(PSY.VariableReserve{PSY.ReserveDown}, RangeReserve),
        ),
    )

    template = OperationsProblemTemplate(network, devices, branches, services)

    return template
end

"""
template_economic_dispatch!(; kwargs...)

Creates an `OperationsProblemTemplate` with default DeviceModels for an Economic Dispatch
problem.

# Example
```julia
template = template_economic_dispatch()
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{Symbol, ServiceModel}` : override default `ServiceModel` settings
"""
function template_economic_dispatch(; kwargs...)
    network = get(kwargs, :network, CopperPlatePowerModel)

    devices = get(
        kwargs,
        :devices,
        Dict(
            :Generators => DeviceModel(PSY.ThermalStandard, ThermalRampLimited),
            :RE => DeviceModel(PSY.RenewableDispatch, RenewableFullDispatch),
            :DistRE => DeviceModel(PSY.RenewableFix, RenewableFixed),
            :Hydro => DeviceModel(PSY.HydroEnergyReservoir, HydroDispatchReservoirFlow),
            :HydroROR => DeviceModel(PSY.HydroDispatch, HydroFixed),
            :Loads => DeviceModel(PSY.PowerLoad, StaticPowerLoad),
            :ILoads => DeviceModel(PSY.InterruptibleLoad, InterruptiblePowerLoad),
        ),
    )

    branches = get(
        kwargs,
        :branches,
        Dict(
            :L => DeviceModel(PSY.Line, StaticLine),
            :T => DeviceModel(PSY.Transformer2W, StaticTransformer),
            :TT => DeviceModel(PSY.TapTransformer, StaticTransformer),
            :DC => DeviceModel(PSY.HVDCLine, HVDCDispatch),
        ),
    )

    services = get(kwargs, :services, Dict())

    template = OperationsProblemTemplate(network, devices, branches, services)

    return template
end
