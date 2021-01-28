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
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
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
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
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
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
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
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `branches::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
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
