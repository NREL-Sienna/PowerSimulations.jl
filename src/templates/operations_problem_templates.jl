struct EconomicDispatchProblem <: AbstractOperationsProblem end

struct UnitCommitmentProblem <: AbstractOperationsProblem end

function _generic_template(; kwargs...)
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
    template = _generic_template(; kwargs...)
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
- `devices::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{Symbol, ServiceModel}` : override default `ServiceModel` settings
"""
function template_economic_dispatch(; kwargs...)

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

    services = get(kwargs, :services, Dict())

    template = _generic_template(devices = devices, services = services; kwargs...)

    return template
end

"""
    EconomicDispatchProblem(system::PSY.System; kwargs...)

Creates an `OperationsProblemTemplate` with default DeviceModels for an EconomicDispatch
problem. Uses the template to create an `OperationsProblem`.

# Example
```julia
ed_problem = EconomicDispatchProblem(system)
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{Symbol, ServiceModel}` : override default `ServiceModel` settings
"""

function EconomicDispatchProblem(system::PSY.System; kwargs...)
    template = template_economic_dispatch(; kwargs...)
    op_problem = OperationsProblem(EconomicDispatchProblem, template, system; kwargs...)
    return op_problem
end

"""
    UnitCommitmentProblem(system::PSY.System; kwargs...)

Creates an `OperationsProblemTemplate` with default DeviceModels for a Unit Commitment
problem. Uses the template to create an `OperationsProblem`.

# Example
```julia
uc_problem = UnitCommitmentProblem(system)
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{Symbol, ServiceModel}` : override default `ServiceModel` settings
"""

function UnitCommitmentProblem(system::PSY.System; kwargs...)
    template = template_unit_commitment(; kwargs...)
    op_problem = OperationsProblem(UnitCommitmentProblem, template, system; kwargs...)
    return op_problem
end

"""
    run_unit_commitment(system::PSY.System; kwargs...)

Creates an `OperationsProblemTemplate` with default DeviceModels for a Unit Commitment
problem. Uses the template to create an `OperationsProblem`. Solves the created operations problem.

# Example
```julia
results = run_unit_commitment(system; optimizer = optimizer)
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{Symbol, ServiceModel}` : override default `ServiceModel` settings
- `optimizer::JuMP Optimizer` : An optimizer is a required key word
"""

function run_unit_commitment(sys::PSY.System; kwargs...)
    template = PSI.template_unit_commitment(; kwargs...)
    op_problem = OperationsProblem(UnitCommitmentProblem, template, sys; kwargs...)
    results = solve_op_problem!(op_problem; kwargs...)
    return results
end

"""
    run_economic_dispatch(system::PSY.System; kwargs...)

Creates an `OperationsProblemTemplate` with default DeviceModels for an EconomicDispatch
problem. Uses the template to create an `OperationsProblem`.

# Example
```julia
results = run_economic_dispatch(system; optimizer = optimizer)
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{Symbol, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{Symbol, ServiceModel}` : override default `ServiceModel` settings
- `optimizer::JuMP optimizer` : a JuMP optimizer is a required key word
"""

function run_economic_dispatch(sys::PSY.System; kwargs...)
    template = PSI.template_economic_dispatch(; kwargs...)
    op_problem = OperationsProblem(EconomicDispatchProblem, template, sys; kwargs...)
    results = solve_op_problem!(op_problem; kwargs...)
    return results
end
