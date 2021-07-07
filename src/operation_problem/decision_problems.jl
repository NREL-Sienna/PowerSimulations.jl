_TEMPLATE_KWARGS = [:network, :devices, :services]

function _filter_kwargs(kwargs)
    template_kwargs = Dict(kwargs)
    build_kwargs = Dict()
    for kw in setdiff(keys(template_kwargs), _TEMPLATE_KWARGS)
        build_kwargs[kw] = pop!(template_kwargs, kw)
    end
    return template_kwargs, build_kwargs
end

"""
    EconomicDispatchProblem(system::PSY.System; kwargs...)

Creates an `ProblemTemplate` with default DeviceModels for an EconomicDispatch
problem. Uses the template to create an `DecisionProblem`.

# Example
```julia
ed_problem = EconomicDispatchProblem(system)
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
- Key word arguments supported by `DecisionProblem`
"""
function EconomicDispatchProblem(system::PSY.System; kwargs...)
    kwargs, problem_kwargs = _filter_kwargs(kwargs)
    output_dir = pop!(problem_kwargs, :output_dir)
    template = template_economic_dispatch(; kwargs...)
    op_problem =
        DecisionProblem(EconomicDispatchProblem, template, system; problem_kwargs...)
    res = build!(op_problem; output_dir = output_dir)
    if res != BuildStatus.BUILT
        error("The EconomicDispatch problem didn't build succesfully")
    end
    return op_problem
end

"""
    UnitCommitmentProblem(system::PSY.System; kwargs...)

Creates an `ProblemTemplate` with default DeviceModels for a Unit Commitment
problem. Uses the template to create an `DecisionProblem`.

# Example
```julia
uc_problem = UnitCommitmentProblem(system)
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
- Key word arguments supported by `DecisionProblem`
"""
function UnitCommitmentProblem(system::PSY.System; kwargs...)
    kwargs, problem_kwargs = _filter_kwargs(kwargs)
    output_dir = pop!(problem_kwargs, :output_dir)
    template = template_unit_commitment(; kwargs...)
    op_problem = DecisionProblem(UnitCommitmentProblem, template, system; problem_kwargs...)
    res = build!(op_problem; output_dir = output_dir)
    if res != BuildStatus.BUILT
        error("The EconomicDispatch problem didn't build succesfully")
    end
    return op_problem
end

"""
    AGCReserveDeployment(system::PSY.System; kwargs...)

Creates an `ProblemTemplate` with default DeviceModels for an AGC Reserve Deplyoment Problem.
Uses the template to create an `DecisionProblem`.

# Example
```julia
agc_problem = AGCReserveDeployment(system)
```

# Accepted Key Words
- Key word arguments supported by `DecisionProblem`
"""
function AGCReserveDeployment(system::PSY.System; kwargs...)
    kwargs, problem_kwargs = _filter_kwargs(kwargs)
    output_dir = pop!(problem_kwargs, :output_dir)
    template = template_agc_reserve_deployment(; kwargs...)
    op_problem = DecisionProblem(UnitCommitmentProblem, template, system; problem_kwargs...)
    res = build!(op_problem; output_dir = output_dir)
    if res != BuildStatus.BUILT
        error("The EconomicDispatch problem didn't build succesfully")
    end
    return op_problem
end

"""
    run_unit_commitment(system::PSY.System; kwargs...)

Creates an `ProblemTemplate` with default DeviceModels for a Unit Commitment
problem. Uses the template to create an `DecisionProblem`. Solves the created operations problem.

# Example
```julia
results = run_unit_commitment(system; optimizer = optimizer)
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
- `optimizer::JuMP Optimizer` : An optimizer is a required key word
- `output_dir::AbstractString`  : Path to save outputs
- Key word arguments supported by `DecisionProblem`
"""

function run_unit_commitment(sys::PSY.System; kwargs...)
    op_problem = UnitCommitmentProblem(sys; kwargs...)
    solve_status = solve!(op_problem)
    return solve_status
end

"""
    run_economic_dispatch(system::PSY.System; kwargs...)

Creates an `ProblemTemplate` with default DeviceModels for an EconomicDispatch
problem. Uses the template to create an `DecisionProblem`.

# Example
```julia
results = run_economic_dispatch(system; optimizer = optimizer)
```

# Accepted Key Words
- `network::Type{<:PM.AbstractPowerModel}` : override default network model settings
- `devices::Dict{String, DeviceModel}` : override default `DeviceModel` settings
- `services::Dict{String, ServiceModel}` : override default `ServiceModel` settings
- `optimizer::JuMP optimizer` : a JuMP optimizer is a required key word
- `output_dir::AbstractString`  : Path to save outputs
- Key word arguments supported by `DecisionProblem`
"""
function run_economic_dispatch(sys::PSY.System; kwargs...)
    op_problem = EconomicDispatchProblem(sys; kwargs...)
    solve_status = solve!(op_problem)
    return solve_status
end
