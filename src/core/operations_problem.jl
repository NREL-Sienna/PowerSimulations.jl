struct GenericOpProblem <: AbstractOperationsProblem end

mutable struct OperationsProblem{M <: AbstractOperationsProblem}
    template::OperationsProblemTemplate
    sys::PSY.System
    psi_container::PSIContainer
end

"""
    OperationsProblem(::Type{M},
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel}=nothing;
    kwargs...) where {M<:AbstractOperationsProblem,
                      T<:PM.AbstractPowerFormulation}
This builds the optimization problem of type M with the specific system and template.
# Arguments
- `::Type{M} where M<:AbstractOperationsProblem`: The abstract operation model type
- `template::OperationsProblemTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.AbstractModel}`: Enables passing a custom JuMP model. Use with care
# Output
- `op_problem::OperationsProblem`: The operation model containing the model type, built JuMP model, Power
Systems system.
# Example
```julia
template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = OperationsProblem(TestOpProblem, template, system)
```
# Accepted Key Words
- `Horizon::Int`: Manually specify the length of the forecast Horizon
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `use_forecast_data::Bool` : If true uses the data in the system forecasts. If false uses the data for current operating point in the system.
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model for StandardPTDFModel networks.
- `optimizer::JuMP.MOI.OptimizerWithAttributes`: The optimizer that will be used in the optimization model.
- `initial_conditions::InitialConditions`: default of Dict{ICKey, Array{InitialCondition}}
- `use_parameters::Bool`: True will substitute will implement formulations using ParameterJuMP parameters. Defatul is false.
- `use_warm_start::Bool` True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
"""
function OperationsProblem(
    ::Type{M},
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem}
    return OperationsProblem{M}(template, sys, jump_model; kwargs...)
end

function OperationsProblem{M}(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem}
    check_kwargs(kwargs, OPERATIONS_ACCEPTED_KWARGS, "OperationsProblem")
    settings = PSISettings(sys; kwargs...)
    return OperationsProblem{M}(template, sys, jump_model, settings)
end

function OperationsProblem{M}(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel},
    settings::PSISettings,
) where {M <: AbstractOperationsProblem}
    op_problem = OperationsProblem{M}(
        template,
        sys,
        PSIContainer(template.transmission, sys, settings, jump_model),
    )
    build!(op_problem)
    return op_problem
end

"""
    OperationsProblem(op_problem::Type{M},
                    ::Type{T},
                    sys::PSY.System,
                    jump_model::Union{Nothing, JuMP.AbstractModel}=nothing;
                    kwargs...) where {M<:AbstractOperationsProblem,
                                      T<:PM.AbstractPowerFormulation}
Return an unbuilt operation problem of type M with the specific system and network model T.
    This constructor doesn't build any device model; it is meant to built device models individually using [`construct_device!`](@ref)
# Arguments
- `::Type{M} where M<:AbstractOperationsProblem`: The abstract operation model type
- `::Type{T} where T<:AbstractPowerModel`: The abstract network formulation
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.AbstractModel}`: Enables passing a custom JuMP model. Use with care
# Output
- `op_problem::OperationsProblem`: The operation model containing the model type, unbuilt JuMP model, Power
Systems system.
# Example
```julia
OpModel = OperationsProblem(MyCustomOpProblem, DCPPowerModel, system)
model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)
construct_device!(op_problem, :Thermal, model)
```
# Accepted Key Words
- `Horizon::Int`: Manually specify the length of the forecast Horizon
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `use_forecast_data::Bool` : If true uses the data in the system forecasts. If false uses the data for current operating point in the system.
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model for StandardPTDFModel networks.
- `optimizer::JuMP.MOI.OptimizerWithAttributes`: The optimizer that will be used in the optimization model.
- `initial_conditions::InitialConditions`: default of Dict{ICKey, Array{InitialCondition}}
- `use_parameters::Bool`: True will substitute will implement formulations using ParameterJuMP parameters. Defatul is false.
- `use_warm_start::Bool` True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
"""
function OperationsProblem(
    ::Type{M},
    ::Type{T},
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem, T <: PM.AbstractPowerModel}
    return OperationsProblem{M}(T, sys, jump_model; kwargs...)
end

function OperationsProblem{M}(
    ::Type{T},
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem, T <: PM.AbstractPowerModel}
    check_kwargs(kwargs, OPERATIONS_ACCEPTED_KWARGS, "OperationsProblem")
    settings = PSISettings(sys; kwargs...)
    return OperationsProblem{M}(
        OperationsProblemTemplate(T),
        sys,
        PSIContainer(T, sys, settings, jump_model),
    )
end

"""
    OperationsProblem(::Type{T},
                    sys::PSY.System,
                    jump_model::Union{Nothing, JuMP.AbstractModel}=nothing;
                    kwargs...) where {M<:AbstractOperationsProblem,
                                      T<:PM.AbstractPowerFormulation}
Return an unbuilt operation problem of type GenericOpProblem with the specific system and network model T.
    This constructor doesn't build any device model; it is meant to built device models individually using [`construct_device!`](@ref)
# Arguments
- `::Type{T} where T<:AbstractPowerModel`: The abstract network formulation
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.AbstractModel}`: Enables passing a custom JuMP model. Use with care
# Output
- `op_problem::OperationsProblem`: The operation model containing the model type, unbuilt JuMP model, Power
Systems system.
# Example
```julia
OpModel = OperationsProblem(DCPPowerModel, system)
model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)
construct_device!(op_problem, :Thermal, model)
```
# Accepted Key Words
- `Horizon::Int`: Manually specify the length of the forecast Horizon
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `use_forecast_data::Bool` : If true uses the data in the system forecasts. If false uses the data for current operating point in the system.
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model for StandardPTDFModel networks.
- `optimizer::JuMP.MOI.OptimizerWithAttributes`: The optimizer that will be used in the optimization model.
- `initial_conditions::InitialConditions`: default of Dict{ICKey, Array{InitialCondition}}
- `use_parameters::Bool`: True will substitute will implement formulations using ParameterJuMP parameters. Defatul is false.
- `use_warm_start::Bool` True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
"""
function OperationsProblem(
    ::Type{T},
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {T <: PM.AbstractPowerModel}
    return OperationsProblem{GenericOpProblem}(T, sys, jump_model; kwargs...)
end

"""
    OperationsProblem(filename::AbstractString)

Construct an OperationsProblem from a serialized file.

# Arguments
- `filename::AbstractString`: path to serialized file
- `jump_model::Union{Nothing, JuMP.AbstractModel}` = nothing: The JuMP model does not get
   serialized. Callers should pass whatever they passed to the original problem.
- `optimizer::Union{Nothing,JuMP.MOI.OptimizerWithAttributes}` = nothing: The optimizer does
   not get serialized. Callers should pass whatever they passed to the original problem.
"""
function OperationsProblem(
    filename::AbstractString;
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing,
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes} = nothing,
)
    return deserialize(
        OperationsProblem,
        filename;
        jump_model = jump_model,
        optimizer = optimizer,
    )
end

get_transmission_ref(op_problem::OperationsProblem) = op_problem.template.transmission
get_devices_ref(op_problem::OperationsProblem) = op_problem.template.devices
get_system(op_problem::OperationsProblem) = op_problem.sys
get_psi_container(op_problem::OperationsProblem) = op_problem.psi_container
get_base_power(op_problem::OperationsProblem) = op_problem.sys.basepower

function reset!(op_problem::OperationsProblem)
    op_problem.psi_container = PSIContainer(
        op_problem.template.transmission,
        op_problem.sys,
        op_problem.psi_container.settings,
        nothing,
    )
    return
end

function set_transmission_model!(
    op_problem::OperationsProblem{M},
    transmission::Type{T},
) where {T <: PM.AbstractPowerModel, M <: AbstractOperationsProblem}
    op_problem.template.transmission = transmission
    reset!(op_problem)
    build!(op_problem)
    return
end

function set_devices_template!(
    op_problem::OperationsProblem{M},
    devices::Dict{Symbol, DeviceModel},
) where {M <: AbstractOperationsProblem}
    op_problem.template.devices = devices
    reset!(op_problem)
    build!(op_problem)
    return
end

function set_branches_template!(
    op_problem::OperationsProblem{M},
    branches::Dict{Symbol, DeviceModel},
) where {M <: AbstractOperationsProblem}
    op_problem.template.branches = branches
    reset!(op_problem)
    build!(op_problem)
    return
end

function set_services_template!(
    op_problem::OperationsProblem{M},
    services::Dict{Symbol, <:ServiceModel},
) where {M <: AbstractOperationsProblem}
    op_problem.template.services = services
    reset!(op_problem)
    build!(op_problem)
    return
end

function set_device_model!(
    op_problem::OperationsProblem{M},
    name::Symbol,
    device::DeviceModel{<:PSY.StaticInjection, <:AbstractDeviceFormulation},
) where {M <: AbstractOperationsProblem}
    if haskey(op_problem.template.devices, name)
        op_problem.template.devices[name] = device
        reset!(op_problem)
        build!(op_problem)
    else
        throw(IS.ConflictingInputsError("Device Model with name $(name) doesn't exist in the model"))
    end
    return
end

function set_branch_model!(
    op_problem::OperationsProblem{M},
    name::Symbol,
    branch::DeviceModel{<:PSY.Branch, <:AbstractDeviceFormulation},
) where {M <: AbstractOperationsProblem}
    if haskey(op_problem.template.branches, name)
        op_problem.template.branches[name] = branch
        reset!(op_problem)
        build!(op_problem)
    else
        throw(IS.ConflictingInputsError("Branch Model with name $(name) doesn't exist in the model"))
    end
    return
end

function set_services_model!(
    op_problem::OperationsProblem{M},
    name::Symbol,
    service::ServiceModel,
) where {M <: AbstractOperationsProblem}
    if haskey(op_problem.template.services, name)
        op_problem.template.services[name] = service
        reset!(op_problem)
        build!(op_problem)
    else
        throw(IS.ConflictingInputsError("Branch Model with name $(name) doesn't exist in the model"))
    end
    return
end

function construct_device!(
    op_problem::OperationsProblem,
    name::Symbol,
    device_model::DeviceModel,
)
    if haskey(op_problem.template.devices, name)
        throw(IS.ConflictingInputsError("Device with model name $(name) already exists in the Opertaion Model"))
    end
    devices_ref = get_devices_ref(op_problem)
    devices_ref[name] = device_model
    construct_device!(
        op_problem.psi_container,
        get_system(op_problem),
        device_model,
        get_transmission_ref(op_problem),
    )
    JuMP.@objective(
        op_problem.psi_container.JuMPmodel,
        MOI.MIN_SENSE,
        op_problem.psi_container.cost_function
    )
    return
end

function construct_network!(op_problem::OperationsProblem)
    construct_network!(op_problem, op_problem.template.transmission)
    return
end

function construct_network!(
    op_problem::OperationsProblem,
    system_formulation::Type{T},
) where {T <: PM.AbstractPowerModel}
    construct_network!(op_problem.psi_container, get_system(op_problem), T)
    return
end

function get_initial_conditions(
    op_problem::OperationsProblem,
    ic::InitialConditionType,
    device::PSY.Device,
)
    psi_container = op_problem.psi_container
    key = ICKey(ic, device)

    return get_initial_conditions(psi_container, key)
end

function build!(op_problem::OperationsProblem{M}) where {M <: AbstractOperationsProblem}
    sys = get_system(op_problem)
    _build!(op_problem.psi_container, op_problem.template, sys)
    return
end

function check_problem_size(psi_container::PSIContainer)
    vars = JuMP.num_variables(psi_container.JuMPmodel)
    cons = 0
    for (exp, c_type) in JuMP.list_of_constraint_types(psi_container.JuMPmodel)
        cons += JuMP.num_constraints(psi_container.JuMPmodel, exp, c_type)
    end
    return "The current total number of variables is $(vars) and total number of constraints is $(cons)"
end

        @debug check_problem_size(psi_container)
    @debug check_problem_size(psi_container)

        @debug check_problem_size(psi_container)
function get_variables_value(op_m::OperationsProblem)
    results_dict = Dict{Symbol, DataFrames.DataFrame}()
    for (k, v) in get_variables(op_m.psi_container)
        results_dict[k] = axis_array_to_dataframe(v)
    end
    return results_dict
end

function get_dual_values(op_m::OperationsProblem)
    return get_dual_values(op_m.psi_container)
end

"""
    solve!(op_problem::OperationsProblem; kwargs...)
This solves the operational model for a single instance and
outputs results of type OperationsProblemResult
# Arguments
- `op_problem::OperationModel = op_problem`: operation model
# Examples
```julia
results = solve!(OpModel)
```
# Accepted Key Words
- `save_path::String`: If a file path is provided the results
automatically get written to feather files
- `optimizer::MOI.OptimizerWithAttributes`: The optimizer that is used to solve the model
"""
function solve!(
    op_problem::OperationsProblem{T};
    kwargs...,
) where {T <: AbstractOperationsProblem}
    check_kwargs(kwargs, OPERATIONS_SOLVE_KWARGS, "Solve")
    timed_log = Dict{Symbol, Any}()
    save_path = get(kwargs, :save_path, nothing)

    if op_problem.psi_container.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
        if !(:optimizer in keys(kwargs))
            error("No Optimizer has been defined, can't solve the operational problem")
        end
        JuMP.set_optimizer(op_problem.psi_container.JuMPmodel, kwargs[:optimizer])
        _,
        timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_problem.psi_container.JuMPmodel)
    else
        _,
        timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_problem.psi_container.JuMPmodel)
    end
    model_status = JuMP.primal_status(op_problem.psi_container.JuMPmodel)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        error("The Operational Problem $(T) status is $(model_status)")
    end
    vars_result = get_variables_value(op_problem)
    param_values = get_parameters_value(get_psi_container(op_problem))
    optimizer_log = get_optimizer_log(op_problem)
    time_stamp = get_time_stamps(op_problem)
    time_stamp = shorten_time_stamp(time_stamp)
    base_power = PSY.get_basepower(op_problem.sys)
    dual_result = get_dual_values(op_problem)
    obj_value = Dict(
        :OBJECTIVE_FUNCTION => JuMP.objective_value(op_problem.psi_container.JuMPmodel),
    )
    basepower = get_base_power(op_problem)
    merge!(optimizer_log, timed_log)

    results = OperationsProblemResults(
        base_power,
        vars_result,
        obj_value,
        optimizer_log,
        time_stamp,
        dual_result,
        param_values,
    )

    !isnothing(save_path) && write_results(results, save_path)

    return results
end

# Function to create a dictionary for the optimizer log of the simulation
function get_optimizer_log(op_m::OperationsProblem)
    psi_container = op_m.psi_container
    optimizer_log = Dict{Symbol, Any}()
    optimizer_log[:obj_value] = JuMP.objective_value(psi_container.JuMPmodel)
    optimizer_log[:termination_status] = JuMP.termination_status(psi_container.JuMPmodel)
    optimizer_log[:primal_status] = JuMP.primal_status(psi_container.JuMPmodel)
    optimizer_log[:dual_status] = JuMP.dual_status(psi_container.JuMPmodel)
    optimizer_log[:solver] = JuMP.solver_name(psi_container.JuMPmodel)

    try
        optimizer_log[:solve_time] = MOI.get(psi_container.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by $(optimizer_log[:solver])")
        optimizer_log[:solve_time] = "Not Supported by $(optimizer_log[:solver])"
    end
    return optimizer_log
end

# Function to create a dictionary for the time series of the simulation
function get_time_stamps(op_problem::OperationsProblem)
    initial_time = PSY.get_forecasts_initial_time(op_problem.sys)
    interval = PSY.get_forecasts_resolution(op_problem.sys)
    horizon = PSY.get_forecasts_horizon(op_problem.sys)
    range_time = collect(initial_time:interval:(initial_time + interval .* horizon))
    time_stamp = DataFrames.DataFrame(Range = range_time[:, 1])

    return time_stamp
end

function write_data(psi_container::PSIContainer, save_path::AbstractString; kwargs...)
    file_type = get(kwargs, :file_type, Feather)
    if file_type == Feather || file_type == CSV
        for (k, v) in get_variables(psi_container)
            file_path = joinpath(save_path, "$(k).$(lowercase("$file_type"))")
            variable = axis_array_to_dataframe(v)
            file_type.write(file_path, variable)
        end
    end
    return
end

function write_data(op_problem::OperationsProblem, save_path::String; kwargs...)
    write_data(op_problem.psi_container, save_path; kwargs...)
    return
end

""" Exports the OpModel JuMP object in MathOptFormat"""
function export_op_model(op_problem::OperationsProblem, save_path::String)
    _write_psi_container(op_problem.psi_container, save_path)
    return
end

################ Functions to debug optimization models#####################################
""" "Each Tuple corresponds to (con_name, internal_index, moi_index)"""
function get_all_constraint_index(op_problem::OperationsProblem)
    con_index = Vector{Tuple{Symbol, Int, Int}}()
    for (key, value) in op_problem.psi_container.constraints
        for (idx, constraint) in enumerate(value)
            moi_index = JuMP.optimizer_index(constraint)
            push!(con_index, (key, idx, moi_index.value))
        end
    end
    return con_index
end

""" "Each Tuple corresponds to (con_name, internal_index, moi_index)"""
function get_all_var_index(op_problem::OperationsProblem)
    var_index = Vector{Tuple{Symbol, Int, Int}}()
    for (key, value) in op_problem.psi_container.variables
        for (idx, variable) in enumerate(value)
            moi_index = JuMP.optimizer_index(variable)
            push!(var_index, (key, idx, moi_index.value))
        end
    end
    return var_index
end

function get_con_index(op_problem::OperationsProblem, index::Int)
    for i in get_all_constraint_index(op_problem::OperationsProblem)
        if i[3] == index
            return op_problem.psi_container.constraints[i[1]].data[i[2]]
        end
    end

    @info "Index not found"
    return
end

function get_var_index(op_problem::OperationsProblem, index::Int)
    for i in get_all_var_index(op_problem::OperationsProblem)
        if i[3] == index
            return op_problem.psi_container.variables[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end

function serialize(op_problem::OperationsProblem, filename::AbstractString)
    # A PowerSystem cannot be serialized in this format because of how it stores
    # time series data. Use its specialized serialization method instead.
    sys_filename = "$(basename(filename))-system-$(IS.get_uuid(op_problem.sys)).json"
    PSY.to_json(op_problem.sys, sys_filename)
    obj = OperationsProblemSerializationWrapper(
        op_problem.template,
        sys_filename,
        op_problem.psi_container.settings_copy,
        typeof(op_problem),
    )
    Serialization.serialize(filename, obj)
    @info "Serialized OperationsProblem to" filename
end

function deserialize(::Type{OperationsProblem}, filename::AbstractString; kwargs...)
    obj = Serialization.deserialize(filename)
    if !(obj isa OperationsProblemSerializationWrapper)
        throw(IS.DataFormatError("deserialized object has incorrect type $(typeof(obj))"))
    end

    if !ispath(obj.sys)
        throw(IS.DataFormatError("PowerSystems.System file $(obj.sys) does not exist"))
    end
    sys = PSY.System(obj.sys)

    return obj.op_problem_type(
        obj.template,
        sys,
        kwargs[:jump_model],
        restore_from_copy(obj.settings; optimizer = kwargs[:optimizer]),
    )
end

struct OperationsProblemSerializationWrapper
    template::OperationsProblemTemplate
    sys::String
    settings::PSISettings
    op_problem_type::DataType
end
