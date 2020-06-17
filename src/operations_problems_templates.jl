struct EconomicDispatchProblem <: PowerSimulationsOperationsProblem end
struct UnitCommitmentProblem <: PowerSimulationsOperationsProblem end
struct AGCReserveDeployment <: PowerSimulationsOperationsProblem end

function _generic_template(; kwargs...)
    network = get(kwargs, :network, CopperPlatePowerModel)

    devices = get(
        kwargs,
        :devices,
        Dict(
            :Generators => DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment),
            :RE => DeviceModel(PSY.RenewableDispatch, RenewableFullDispatch),
            :DistRE => DeviceModel(PSY.RenewableFix, FixedOutput),
            :Hydro => DeviceModel(PSY.HydroEnergyReservoir, HydroDispatchRunOfRiver),
            :HydroROR => DeviceModel(PSY.HydroDispatch, HydroDispatchRunOfRiver),
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
            :DistRE => DeviceModel(PSY.RenewableFix, FixedOutput),
            :Hydro => DeviceModel(PSY.HydroEnergyReservoir, HydroDispatchReservoirFlow),
            :HydroROR => DeviceModel(PSY.HydroDispatch, FixedOutput),
            :Loads => DeviceModel(PSY.PowerLoad, StaticPowerLoad),
            :ILoads => DeviceModel(PSY.InterruptibleLoad, InterruptiblePowerLoad),
        ),
    )

    services = get(kwargs, :services, Dict())

    template = _generic_template(devices = devices, services = services; kwargs...)

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
    devices = Dict(
        :Generators => DeviceModel(PSY.ThermalStandard, FixedOutput),
        :Ren => DeviceModel(PSY.RenewableDispatch, FixedOutput),
        :Loads => DeviceModel(PSY.PowerLoad, StaticPowerLoad),
        :Hydro => DeviceModel(PSY.HydroEnergyReservoir, FixedOutput),
        :HydroROR => DeviceModel(PSY.HydroDispatch, FixedOutput),
        :RenFx => DeviceModel(PSY.RenewableFix, FixedOutput),
        :Regulation_thermal => DeviceModel(
            PSY.RegulationDevice{PSY.ThermalStandard},
            DeviceLimitedRegulation,
        ),
        :Regulation_hydro_dispatch => DeviceModel(
            PSY.RegulationDevice{PSY.HydroDispatch},
            ReserveLimitedRegulation,
        ),
        :Regulation_hydro_reservoir => DeviceModel(
            PSY.RegulationDevice{PSY.HydroEnergyReservoir},
            ReserveLimitedRegulation,
        ),
    )
    services = Dict(:AGC => ServiceModel(PSY.AGC, PIDSmoothACE))
    template = _generic_template(
        network = PSI.AreaBalancePowerModel,
        devices = devices,
        branches = Dict(),
        services = services;
        kwargs...,
    )
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
- Key word arguments supported by `OperationsProblem`
"""

function EconomicDispatchProblem(system::PSY.System; kwargs...)
    kwargs = Dict(kwargs)
    template_kwargs = Dict()
    for kw in setdiff(keys(kwargs), OPERATIONS_ACCEPTED_KWARGS)
        template_kwargs[kw] = pop!(kwargs, kw)
    end

    template = template_economic_dispatch(; template_kwargs...)
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
- Key word arguments supported by `OperationsProblem`
"""
function UnitCommitmentProblem(system::PSY.System; kwargs...)
    kwargs = Dict(kwargs)
    template_kwargs = Dict()
    for kw in setdiff(keys(kwargs), OPERATIONS_ACCEPTED_KWARGS)
        template_kwargs[kw] = pop!(kwargs, kw)
    end

    template = template_unit_commitment(; template_kwargs...)
    op_problem = OperationsProblem(UnitCommitmentProblem, template, system; kwargs...)
    return op_problem
end

"""
    AGCReserveDeployment(system::PSY.System; kwargs...)

Creates an `OperationsProblemTemplate` with default DeviceModels for an AGC Reserve Deplyoment Problem.
Uses the template to create an `OperationsProblem`.

# Example
```julia
agc_problem = AGCReserveDeployment(system)
```

# Accepted Key Words
- Key word arguments supported by `OperationsProblem`
"""
function AGCReserveDeployment(system::PSY.System; kwargs...)
    kwargs = Dict(kwargs)
    template_kwargs = Dict()
    for kw in setdiff(keys(kwargs), OPERATIONS_ACCEPTED_KWARGS)
        template_kwargs[kw] = pop!(kwargs, kw)
    end

    template = template_agc_reserve_deployment(; template_kwargs...)
    op_problem = OperationsProblem(AGCReserveDeployment, template, system; kwargs...)
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
- `savepath::AbstractString`  : Path to save results
- Key word arguments supported by `OperationsProblem`
"""

function run_unit_commitment(sys::PSY.System; kwargs...)
    solve_kwargs = Dict()
    for kw in OPERATIONS_SOLVE_KWARGS
        haskey(kwargs, kw) && (solve_kwargs[kw] = kwargs[kw])
    end
    op_problem = UnitCommitmentProblem(sys; kwargs...)
    results = solve!(op_problem; solve_kwargs...)
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
- `savepath::AbstractString`  : Path to save results
- Key word arguments supported by `OperationsProblem`
"""

function run_economic_dispatch(sys::PSY.System; kwargs...)
    solve_kwargs = Dict()
    for kw in OPERATIONS_SOLVE_KWARGS
        haskey(kwargs, kw) && (solve_kwargs[kw] = kwargs[kw])
    end
    op_problem = EconomicDispatchProblem(sys; kwargs...)
    results = solve!(op_problem; solve_kwargs...)
    return results
end
