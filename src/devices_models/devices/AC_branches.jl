
# Note: Any future concrete formulation requires the definition of

# construct_device!(
#     ::OptimizationContainer,
#     ::PSY.System,
#     ::DeviceModel{<:PSY.ACBranch, MyNewFormulation},
#     ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
# ) = nothing

#

# Not implemented yet
# struct TapControl <: AbstractBranchFormulation end

#################################### Branch Variables ##################################################
# Because of the way we integrate with PowerModels, most of the time PowerSimulations will create variables
# for the branch flows either in AC or DC.

#! format: off
get_variable_binary(::FlowActivePowerVariable, ::Type{<:PSY.ACBranch}, ::AbstractBranchFormulation,) = false
get_variable_binary(::PhaseShifterAngle, ::Type{PSY.PhaseShiftingTransformer}, ::AbstractBranchFormulation,) = false

get_parameter_multiplier(::FixValueParameter, ::PSY.ACBranch, ::AbstractBranchFormulation) = 1.0
get_parameter_multiplier(::LowerBoundValueParameter, ::PSY.ACBranch, ::AbstractBranchFormulation) = 1.0
get_parameter_multiplier(::UpperBoundValueParameter, ::PSY.ACBranch, ::AbstractBranchFormulation) = 1.0

get_variable_multiplier(::PhaseShifterAngle, d::PSY.PhaseShiftingTransformer, ::PhaseAngleControl) = 1.0/PSY.get_x(d)

get_multiplier_value(::AbstractDynamicBranchRatingTimeSeriesParameter, d::PSY.ACBranch, ::StaticBranch) = 1.0/PSY.get_base_power(d)


get_initial_conditions_device_model(::OperationModel, ::DeviceModel{T, U}) where {T <: PSY.ACBranch, U <: AbstractBranchFormulation} = DeviceModel(T, U)

#### Properties of slack variables
get_variable_binary(::FlowActivePowerSlackUpperBound, ::Type{<:PSY.ACBranch}, ::AbstractBranchFormulation,) = false
get_variable_binary(::FlowActivePowerSlackLowerBound, ::Type{<:PSY.ACBranch}, ::AbstractBranchFormulation,) = false
# These two methods are defined to avoid ambiguities
get_variable_binary(::FlowActivePowerSlackUpperBound, ::Type{<:PSY.TwoTerminalGenericHVDCLine}, ::AbstractTwoTerminalDCLineFormulation,) = false
get_variable_binary(::FlowActivePowerSlackLowerBound, ::Type{<:PSY.TwoTerminalGenericHVDCLine}, ::AbstractTwoTerminalDCLineFormulation,) = false
get_variable_binary(::HVDCPiecewiseLossVariable, ::Type{<:PSY.TwoTerminalGenericHVDCLine}, ::AbstractTwoTerminalDCLineFormulation,) = false
get_variable_binary(::HVDCActivePowerReceivedFromVariable, ::Type{<:PSY.TwoTerminalGenericHVDCLine}, ::AbstractTwoTerminalDCLineFormulation,) = false
get_variable_binary(::HVDCActivePowerReceivedToVariable, ::Type{<:PSY.TwoTerminalGenericHVDCLine}, ::AbstractTwoTerminalDCLineFormulation,) = false
get_variable_binary(::HVDCPiecewiseBinaryLossVariable, ::Type{<:PSY.TwoTerminalGenericHVDCLine}, ::AbstractTwoTerminalDCLineFormulation,) = true
get_variable_upper_bound(::FlowActivePowerSlackUpperBound, ::PSY.ACBranch, ::AbstractBranchFormulation) = nothing
get_variable_lower_bound(::FlowActivePowerSlackUpperBound, ::PSY.ACBranch, ::AbstractBranchFormulation) = 0.0
get_variable_upper_bound(::FlowActivePowerSlackLowerBound, ::PSY.ACBranch, ::AbstractBranchFormulation) = nothing
get_variable_lower_bound(::FlowActivePowerSlackLowerBound, ::PSY.ACBranch, ::AbstractBranchFormulation) = 0.0

#! format: on
function get_default_time_series_names(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.ACBranch, V <: AbstractBranchFormulation}
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.ACBranch, V <: AbstractBranchFormulation}
    return Dict{String, Any}()
end
#################################### Flow Variable Bounds ##################################################
# Additional Method to be able to filter the branches that are not in the PTDF matrix
function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    network_model::NetworkModel{<:AbstractPTDFModel},
    devices::IS.FlattenIteratorWrapper{U},
    formulation::AbstractBranchFormulation,
) where {
    T <: Union{
        FlowActivePowerVariable,
        FlowActivePowerSlackUpperBound,
        FlowActivePowerSlackLowerBound,
    },
    U <: PSY.ACBranch}
    time_steps = get_time_steps(container)

    network_reduction = get_network_reduction(network_model)
    branch_names = PNM.get_retained_branches_names(network_reduction)

    branches_in_ptdf =
        [b for b in devices if PSY.get_name(b) in branch_names]

    variable = add_variable_container!(
        container,
        T(),
        U,
        PSY.get_name.(branches_in_ptdf),
        time_steps,
    )

    for d in branches_in_ptdf
        name = PSY.get_name(d)
        # Don't check if names are present when the PTDF has less branches than system
        for t in time_steps
            variable[name, t] = JuMP.@variable(
                get_jump_model(container),
                base_name = "$(T)_$(U)_{$(name), $(t)}",
            )
            ub = get_variable_upper_bound(T(), d, formulation)
            ub !== nothing && JuMP.set_upper_bound(variable[name, t], ub)

            lb = get_variable_lower_bound(T(), d, formulation)
            lb !== nothing && JuMP.set_lower_bound(variable[name, t], lb)
        end
    end
    return
end

function add_variables!(
    container::OptimizationContainer,
    ::Type{FlowActivePowerVariable},
    network_model::NetworkModel{CopperPlatePowerModel},
    devices::IS.FlattenIteratorWrapper{T},
    formulation::U,
) where {T <: PSY.Branch, U <: AbstractBranchFormulation}
    inter_network_branches = T[]
    for d in devices
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        if ref_bus_from != ref_bus_to
            push!(inter_network_branches, d)
        else
            @warn(
                "HVDC Line $(PSY.get_name(d)) is in the same subnetwork, so the line will not be modeled."
            )
        end
    end
    if !isempty(inter_network_branches)
        add_variables!(container, FlowActivePowerVariable, inter_network_branches, U())
    end
    return
end

function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{<:PM.AbstractDCPModel},
) where {B <: PSY.ACBranch}
    var = get_variable(container, FlowActivePowerVariable(), B)

    network_reduction = get_network_reduction(network_model)
    removed_branches_names = PNM.get_removed_branches(network_reduction)

    for d in devices
        name = PSY.get_name(d)
        if name ∈ removed_branches_names
            continue
        end
        for t in get_time_steps(container)
            JuMP.set_upper_bound(var[name, t], PSY.get_rating(d))
            JuMP.set_lower_bound(var[name, t], -1.0 * PSY.get_rating(d))
        end
    end
    return
end

function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {B <: PSY.ACBranch}
    vars = [
        get_variable(container, FlowActivePowerFromToVariable(), B),
        get_variable(container, FlowActivePowerToFromVariable(), B),
    ]

    time_steps = get_time_steps(container)
    network_reduction = get_network_reduction(network_model)
    removed_branches_names = PNM.get_removed_branches(network_reduction)

    for d in devices
        name = PSY.get_name(d)
        if name ∈ removed_branches_names
            continue
        end
        for t in time_steps, var in vars
            JuMP.set_upper_bound(var[name, t], PSY.get_rating(d))
            JuMP.set_lower_bound(var[name, t], -1.0 * PSY.get_rating(d))
        end
    end
    return
end

################################## PWL Loss Variables ##################################

function _check_pwl_loss_model(devices)
    first_loss = PSY.get_loss(first(devices))
    first_loss_type = typeof(first_loss)
    for d in devices
        loss = PSY.get_loss(d)
        if !isa(loss, first_loss_type)
            error(
                "Not all TwoTerminal HVDC lines have the same loss model data. Check that all loss models are LinearCurve or PiecewiseIncrementalCurve",
            )
        end
        if isa(first_loss, PSY.PiecewiseIncrementalCurve)
            len_first_loss = length(PSY.get_slopes(first_loss))
            len_loss = length(PSY.get_slopes(loss))
            if len_first_loss != len_loss
                error(
                    "Different length of PWL segments for TwoTerminal HVDC losses are not supported. Check that all HVDC data have the same amount of PWL segments.",
                )
            end
        end
    end
end

function _add_dense_pwl_loss_variables!(
    container::OptimizationContainer,
    devices,
    model::DeviceModel{D, HVDCTwoTerminalPiecewiseLoss},
) where {D <: TwoTerminalHVDCTypes}
    # Check if type and length of PWL loss model are the same for all devices
    _check_pwl_loss_model(devices)

    # Create Variables
    time_steps = get_time_steps(container)
    settings = get_settings(container)
    formulation = HVDCTwoTerminalPiecewiseLoss()
    T = HVDCPiecewiseLossVariable
    binary = get_variable_binary(T(), D, formulation)
    first_loss = PSY.get_loss(first(devices))
    if isa(first_loss, PSY.LinearCurve)
        len_segments = 4 # 2*1 + 2
    elseif isa(first_loss, PSY.PiecewiseIncrementalCurve)
        len_segments = 2 * length(PSY.get_slopes(first_loss)) + 2
    else
        error("Should not be here")
    end

    segments = ["pwl_$i" for i in 1:len_segments]
    T = HVDCPiecewiseLossVariable
    variable = add_variable_container!(
        container,
        T(),
        D,
        [PSY.get_name(d) for d in devices],
        segments,
        time_steps,
    )

    for t in time_steps, s in segments, d in devices
        name = PSY.get_name(d)
        variable[name, s, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "$(T)_$(D)_{$(name), $(s), $(t)}",
            binary = binary
        )
        ub = get_variable_upper_bound(T(), d, formulation)
        ub !== nothing && JuMP.set_upper_bound(variable[name, s, t], ub)

        lb = get_variable_lower_bound(T(), d, formulation)
        lb !== nothing && JuMP.set_lower_bound(variable[name, s, t], lb)

        if get_warm_start(settings)
            init = get_variable_warm_start_value(T(), d, formulation)
            init !== nothing && JuMP.set_start_value(variable[name, s, t], init)
        end
    end
end

# Full Binary
function _add_sparse_pwl_loss_variables!(
    container::OptimizationContainer,
    devices,
    ::DeviceModel{D, HVDCTwoTerminalPiecewiseLoss},
) where {D <: TwoTerminalHVDCTypes}
    # Check if type and length of PWL loss model are the same for all devices
    #_check_pwl_loss_model(devices)

    # Create Variables
    time_steps = get_time_steps(container)
    settings = get_settings(container)
    formulation = HVDCTwoTerminalPiecewiseLoss()
    T = HVDCPiecewiseLossVariable
    binary_T = get_variable_binary(T(), D, formulation)
    U = HVDCPiecewiseBinaryLossVariable
    binary_U = get_variable_binary(U(), D, formulation)
    first_loss = PSY.get_loss(first(devices))
    if isa(first_loss, PSY.LinearCurve)
        len_segments = 3 # 2*1 + 1
    elseif isa(first_loss, PSY.PiecewiseIncrementalCurve)
        len_segments = 2 * length(PSY.get_slopes(first_loss)) + 1
    else
        error("Should not be here")
    end

    var_container = lazy_container_addition!(container, T(), D)
    var_container_binary = lazy_container_addition!(container, U(), D)

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps
            pwlvars = Array{JuMP.VariableRef}(undef, len_segments)
            pwlvars_bin = Array{JuMP.VariableRef}(undef, len_segments)
            for i in 1:len_segments
                pwlvars[i] =
                    var_container[(name, i, t)] = JuMP.@variable(
                        get_jump_model(container),
                        base_name = "$(T)_$(name)_{pwl_$(i), $(t)}",
                        binary = binary_T
                    )
                ub = get_variable_upper_bound(T(), d, formulation)
                ub !== nothing && JuMP.set_upper_bound(var_container[name, i, t], ub)

                lb = get_variable_lower_bound(T(), d, formulation)
                lb !== nothing && JuMP.set_lower_bound(var_container[name, i, t], lb)

                pwlvars_bin[i] =
                    var_container_binary[(name, i, t)] = JuMP.@variable(
                        get_jump_model(container),
                        base_name = "$(U)_$(name)_{pwl_$(i), $(t)}",
                        binary = binary_U
                    )
            end
        end
    end
end

################################## Rate Limits constraint_infos ############################

"""
Min and max limits for Abstract Branch Formulation
"""
function get_min_max_limits(
    device::PSY.ACBranch,
    ::Type{<:ConstraintType},
    ::Type{<:AbstractBranchFormulation},
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    return (min = -1 * PSY.get_rating(device), max = PSY.get_rating(device))
end

"""
Min and max limits for Abstract Branch Formulation
"""
function get_min_max_limits(
    ::PSY.PhaseShiftingTransformer,
    ::Type{PhaseAngleControlLimit},
    ::Type{PhaseAngleControl},
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    return (min = -π / 2, max = π / 2)
end

function _get_device_dynamic_branch_rating_time_series(
    param_container::ParameterContainer,
    device::PSY.ACBranch,
    ts_name::String,
    ts_type::DataType,
)
    device_dlr_params = []
    if PSY.has_time_series(device, ts_type, ts_name)
        device_dlr_params = get_parameter_column_refs(param_container, get_name(device))
    end
    return device_dlr_params
end

"""
Add branch rate limit constraints for ACBranch with AbstractActivePowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    device_model::DeviceModel{T, U},
    network_model::NetworkModel{V},
) where {
    T <: PSY.ACBranch,
    U <: AbstractBranchFormulation,
    V <: PM.AbstractActivePowerModel,
}
    time_steps = get_time_steps(container)
    network_reduction = get_network_reduction(network_model)
    if isempty(network_reduction.reductions)
        device_names = [PSY.get_name(d) for d in devices]
    else
        device_names = PNM.get_retained_branches(network_reduction)  #Don't need added branches here?
    end

    con_lb =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            device_names,
            time_steps;
            meta = "lb",
        )
    con_ub =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            device_names,
            time_steps;
            meta = "ub",
        )

    array = get_variable(container, FlowActivePowerVariable(), T)

    use_slacks = get_use_slacks(device_model)
    if use_slacks
        slack_ub = get_variable(container, FlowActivePowerSlackUpperBound(), T)
        slack_lb = get_variable(container, FlowActivePowerSlackLowerBound(), T)
    end

    has_dlr_ts =
        haskey(get_time_series_names(device_model), DynamicBranchRatingTimeSeriesParameter)

    if has_dlr_ts
        ts_name =
            get_time_series_names(device_model)[DynamicBranchRatingTimeSeriesParameter]
        ts_type = get_default_time_series_type(container)
        param_container =
            get_parameter(container, DynamicBranchRatingTimeSeriesParameter(), T)
        mult = get_multiplier_array(param_container)
    end

    for device in devices
        ci_name = PSY.get_name(device)
        if !(ci_name ∈ PNM.get_retained_branches_names(network_reduction))
            continue
        end

        if has_dlr_ts
            device_dynamic_branch_rating_ts =
                _get_device_dynamic_branch_rating_time_series(
                    param_container,
                    device,
                    ts_name,
                    ts_type)
        end

        limits = get_min_max_limits(device, RateLimitConstraint, U) # depends on constraint type and formulation type

        for t in time_steps
            if has_dlr_ts && !isempty(device_dynamic_branch_rating_ts)
                limits = (
                    min = -1 * device_dynamic_branch_rating_ts[t] * mult[ci_name, t],
                    max = device_dynamic_branch_rating_ts[t] * mult[ci_name, t],
                ) #update limits
            end

            con_ub[ci_name, t] =
                JuMP.@constraint(get_jump_model(container),
                    array[ci_name, t] - (use_slacks ? slack_ub[ci_name, t] : 0.0) <=
                    limits.max)
            con_lb[ci_name, t] =
                JuMP.@constraint(get_jump_model(container),
                    array[ci_name, t] + (use_slacks ? slack_lb[ci_name, t] : 0.0) >=
                    limits.min)
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{RateLimitConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: PSY.ACBranch, U <: AbstractBranchFormulation}
    inter_network_branches = T[]
    for d in devices
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        if ref_bus_from != ref_bus_to
            push!(inter_network_branches, d)
        end
    end
    if !isempty(inter_network_branches)
        add_range_constraints!(
            container,
            RateLimitConstraint,
            FlowActivePowerVariable,
            devices,
            model,
            CopperPlatePowerModel,
        )
    end
    return
end

function _constraint_without_slacks!(
    container::OptimizationContainer,
    constraint::JuMPConstraintArray,
    rating_data::Vector{Tuple{String, Float64}},
    time_steps::UnitRange{Int64},
    removed_branches_names::Set{String},
    var1::JuMPVariableArray,
    var2::JuMPVariableArray,
)
    for (branch_name, branch_rate) in rating_data
        if branch_name ∈ removed_branches_names
            continue
        end
        for t in time_steps
            constraint[branch_name, t] = JuMP.@constraint(
                get_jump_model(container),
                var1[branch_name, t]^2 + var2[branch_name, t]^2 <= branch_rate^2
            )
        end
    end
    return
end

function _constraint_with_slacks!(
    container::OptimizationContainer,
    constraint::JuMPConstraintArray,
    rating_data::Vector{Tuple{String, Float64}},
    time_steps::UnitRange{Int64},
    removed_branches_names::Set{String},
    var1::JuMPVariableArray,
    var2::JuMPVariableArray,
    slack_ub::JuMPVariableArray,
)
    for (branch_name, branch_rate) in rating_data
        if branch_name ∈ removed_branches_names
            continue
        end
        for t in time_steps
            constraint[branch_name, t] = JuMP.@constraint(
                get_jump_model(container),
                var1[branch_name, t]^2 + var2[branch_name, t]^2 -
                slack_ub[branch_name, t] <= branch_rate^2
            )
        end
    end
    return
end

"""
Add rate limit from to constraints for ACBranch with AbstractPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitConstraintFromTo},
    devices::IS.FlattenIteratorWrapper{B},
    device_model::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{T},
) where {B <: PSY.ACBranch, T <: PM.AbstractPowerModel}
    rating_data = [(PSY.get_name(h), PSY.get_rating(h)) for h in devices]

    time_steps = get_time_steps(container)
    var1 = get_variable(container, FlowActivePowerFromToVariable(), B)
    var2 = get_variable(container, FlowReactivePowerFromToVariable(), B)
    add_constraints_container!(
        container,
        cons_type(),
        B,
        [r[1] for r in rating_data],
        time_steps,
    )
    constraint = get_constraint(container, cons_type(), B)

    network_reduction = get_network_reduction(network_model)
    removed_branches_names = PNM.get_removed_branches(network_reduction)

    use_slacks = get_use_slacks(device_model)
    if use_slacks
        slack_ub = get_variable(container, FlowActivePowerSlackUpperBound(), B)
        _constraint_with_slacks!(
            container,
            constraint,
            rating_data,
            time_steps,
            removed_branches_names,
            var1,
            var2,
            slack_ub,
        )
    end

    _constraint_without_slacks!(
        container,
        constraint,
        rating_data,
        time_steps,
        removed_branches_names,
        var1,
        var2,
    )

    return
end

"""
Add rate limit to from constraints for ACBranch with AbstractPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitConstraintToFrom},
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{T},
) where {B <: PSY.ACBranch, T <: PM.AbstractPowerModel}
    rating_data = [(PSY.get_name(h), PSY.get_rating(h)) for h in devices]

    time_steps = get_time_steps(container)
    var1 = get_variable(container, FlowActivePowerToFromVariable(), B)
    var2 = get_variable(container, FlowReactivePowerToFromVariable(), B)
    add_constraints_container!(
        container,
        cons_type(),
        B,
        [r[1] for r in rating_data],
        time_steps,
    )
    constraint = get_constraint(container, cons_type(), B)

    network_reduction = get_network_reduction(network_model)
    removed_branches_names = PNM.get_removed_branches(network_reduction)

    for r in rating_data
        if r[1] ∈ removed_branches_names
            continue
        end
        for t in time_steps
            constraint[r[1], t] = JuMP.@constraint(
                get_jump_model(container),
                var1[r[1], t]^2 + var2[r[1], t]^2 <= r[2]^2
            )
        end
    end
    return
end

const ValidPTDFS = Union{
    PNM.PTDF{
        Tuple{Vector{Int}, Vector{Tuple{Int64, Int64}}},
        Tuple{Dict{Int64, Int64}, Dict{Tuple{Int64, Int64}, Int64}},
        Matrix{Float64},
    },
    PNM.VirtualPTDF{
        Tuple{Vector{Tuple{Int64, Int64}}, Vector{Int64}},
        Tuple{Dict{Tuple{Int64, Int64}, Int64}, Dict{Int64, Int64}},
    },}

function _make_flow_expressions!(
    jump_model::JuMP.Model,
    name::String,
    time_steps::UnitRange{Int},
    ptdf_col::AbstractVector{Float64},
    nodal_balance_expressions::Matrix{JuMP.AffExpr},
)
    @debug Threads.threadid() name
    expressions = Vector{JuMP.AffExpr}(undef, length(time_steps))
    for t in time_steps
        expressions[t] = JuMP.@expression(
            jump_model,
            sum(
                ptdf_col[i] * nodal_balance_expressions[i, t] for
                i in 1:length(ptdf_col)
            )
        )
    end
    return name, expressions
    # change when using the not concurrent version
    #return expressions
end

function _make_flow_expressions!(
    container::OptimizationContainer,
    branches::Vector{String},
    time_steps::UnitRange{Int},
    ptdf::ValidPTDFS,
    nodal_balance_expressions::JuMPAffineExpressionDArray,
    branch_Type::DataType,
)
    branch_flow_expr = add_expression_container!(container,
        PTDFBranchFlow(),
        branch_Type,
        branches,
        time_steps,
    )

    jump_model = get_jump_model(container)

    tasks = map(branches) do name
        ptdf_col = ptdf[name, :]
        Threads.@spawn _make_flow_expressions!(
            jump_model,
            name,
            time_steps,
            ptdf_col,
            nodal_balance_expressions.data,
        )
    end
    for task in tasks
        name, expressions = fetch(task)
        branch_flow_expr[name, :] .= expressions
    end

    #= Leaving serial code commented out for debugging purposes in the future
    for name in branches
        ptdf_col = ptdf[name, :]
        branch_flow_expr[name, :] .= _make_flow_expressions!(
            jump_model,
            name,
            time_steps,
            ptdf_col,
            nodal_balance_expressions.data,
        )
    end
    =#

    return branch_flow_expr
end
"""
Add network flow constraints for ACBranch and NetworkModel with <: AbstractPTDFModel
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{NetworkFlowConstraint},
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {B <: PSY.ACBranch}
    ptdf = get_PTDF_matrix(network_model)
    # This is a workaround to not call the same list comprehension to find
    # The subset of branches of type B in the PTDF
    flow_variables = get_variable(container, FlowActivePowerVariable(), B)
    @show flow_variables
    @show typeof(flow_variables)
    branches = flow_variables.axes[1]
    time_steps = get_time_steps(container)
    branch_flow = add_constraints_container!(
        container,
        NetworkFlowConstraint(),
        B,
        branches,
        time_steps,
    )
    nodal_balance_expressions =
        get_expression(container, ActivePowerBalance(), PSY.ACBus)
    flow_variables = get_variable(container, FlowActivePowerVariable(), B)
    branch_flow_expr = _make_flow_expressions!(
        container,
        branches,
        time_steps,
        ptdf,
        nodal_balance_expressions,
        B,
    )
    jump_model = get_jump_model(container)
    for name in branches
        for t in time_steps
            branch_flow[name, t] = JuMP.@constraint(
                jump_model,
                branch_flow_expr[name, t] - flow_variables[name, t] == 0.0
            )
        end
    end
    return
end

"""
Add network flow constraints for PhaseShiftingTransformer and NetworkModel with <: AbstractPTDFModel
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{NetworkFlowConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, PhaseAngleControl},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: PSY.PhaseShiftingTransformer}
    ptdf = get_PTDF_matrix(network_model)
    branches = PSY.get_name.(devices)
    time_steps = get_time_steps(container)
    branch_flow = add_constraints_container!(
        container,
        NetworkFlowConstraint(),
        T,
        branches,
        time_steps,
    )
    nodal_balance_expressions = get_expression(container, ActivePowerBalance(), PSY.ACBus)
    flow_variables = get_variable(container, FlowActivePowerVariable(), T)
    angle_variables = get_variable(container, PhaseShifterAngle(), T)
    jump_model = get_jump_model(container)
    for br in devices
        name = PSY.get_name(br)
        ptdf_col = ptdf[name, :]
        inv_x = 1 / PSY.get_x(br)
        for t in time_steps
            branch_flow[name, t] = JuMP.@constraint(
                jump_model,
                sum(
                    ptdf_col[i] * nodal_balance_expressions.data[i, t] for
                    i in 1:length(ptdf_col)
                ) + inv_x * angle_variables[name, t] - flow_variables[name, t] == 0.0
            )
        end
    end
end

"""
Min and max limits for monitored line
"""
function get_min_max_limits(
    device::PSY.MonitoredLine,
    ::Type{<:ConstraintType},
    ::Type{<:AbstractBranchFormulation},
)
    if PSY.get_flow_limits(device).to_from != PSY.get_flow_limits(device).from_to
        @warn(
            "Flow limits in Line $(PSY.get_name(device)) aren't equal. The minimum will be used in formulation $(T)"
        )
    end
    limit = min(
        PSY.get_rating(device),
        PSY.get_flow_limits(device).to_from,
        PSY.get_flow_limits(device).from_to,
    )
    minmax = (min = -1 * limit, max = limit)
    return minmax
end

############################## Flow Limits Constraints #####################################
"""
Add branch flow constraints for monitored lines with DC Power Model
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{FlowLimitConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::NetworkModel{V},
) where {
    T <: Union{PSY.PhaseShiftingTransformer, PSY.MonitoredLine},
    U <: AbstractBranchFormulation,
    V <: PM.AbstractDCPModel,
}
    add_range_constraints!(
        container,
        FlowLimitConstraint,
        FlowActivePowerVariable,
        devices,
        model,
        V,
    )
    return
end

"""
Don't add branch flow constraints for monitored lines if formulation is StaticBranchUnbounded
"""
function add_constraints!(
    ::OptimizationContainer,
    ::Type{RateLimitConstraintFromTo},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::NetworkModel{V},
) where {
    T <: PSY.MonitoredLine,
    U <: StaticBranchUnbounded,
    V <: PM.AbstractActivePowerModel,
}
    return
end

"""
Min and max limits for flow limit from-to constraint
"""
function get_min_max_limits(
    device::PSY.MonitoredLine,
    ::Type{FlowLimitFromToConstraint},
    ::Type{<:AbstractBranchFormulation},
)
    if PSY.get_flow_limits(device).to_from != PSY.get_flow_limits(device).from_to
        @warn(
            "Flow limits in Line $(PSY.get_name(device)) aren't equal. The minimum will be used in formulation $(T)"
        )
    end
    return (
        min = -1 * PSY.get_flow_limits(device).from_to,
        max = PSY.get_flow_limits(device).from_to,
    )
end

"""
Min and max limits for flow limit to-from constraint
"""
function get_min_max_limits(
    device::PSY.MonitoredLine,
    ::Type{FlowLimitToFromConstraint},
    ::Type{<:AbstractBranchFormulation},
)
    if PSY.get_flow_limits(device).to_from != PSY.get_flow_limits(device).from_to
        @warn(
            "Flow limits in Line $(PSY.get_name(device)) aren't equal. The minimum will be used in formulation $(T)"
        )
    end
    return (
        min = -1 * PSY.get_flow_limits(device).to_from,
        max = PSY.get_flow_limits(device).to_from,
    )
end

"""
Don't add branch flow constraints for monitored lines if formulation is StaticBranchUnbounded
"""
function add_constraints!(
    ::OptimizationContainer,
    ::Type{FlowLimitToFromConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::NetworkModel{V},
) where {
    T <: PSY.MonitoredLine,
    U <: StaticBranchUnbounded,
    V <: PM.AbstractActivePowerModel,
}
    return
end

"""
Add phase angle limits for phase shifters
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{PhaseAngleControlLimit},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, PhaseAngleControl},
    ::NetworkModel{U},
) where {T <: PSY.PhaseShiftingTransformer, U <: PM.AbstractActivePowerModel}
    add_range_constraints!(
        container,
        PhaseAngleControlLimit,
        PhaseShifterAngle,
        devices,
        model,
        U,
    )
    return
end

"""
Add network flow constraints for PhaseShiftingTransformer and NetworkModel with PM.DCPPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{NetworkFlowConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, PhaseAngleControl},
    ::NetworkModel{PM.DCPPowerModel},
) where {T <: PSY.PhaseShiftingTransformer}
    time_steps = get_time_steps(container)
    flow_variables = get_variable(container, FlowActivePowerVariable(), T)
    ps_angle_variables = get_variable(container, PhaseShifterAngle(), T)
    bus_angle_variables = get_variable(container, VoltageAngle(), PSY.ACBus)
    jump_model = get_jump_model(container)
    branch_flow = add_constraints_container!(
        container,
        NetworkFlowConstraint(),
        T,
        axes(flow_variables)[1],
        time_steps,
    )

    for br in devices
        name = PSY.get_name(br)
        inv_x = 1.0 / PSY.get_x(br)
        flow_variables_ = flow_variables[name, :]
        from_bus = PSY.get_name(PSY.get_from(PSY.get_arc(br)))
        to_bus = PSY.get_name(PSY.get_to(PSY.get_arc(br)))
        angle_variables_ = ps_angle_variables[name, :]
        bus_angle_from = bus_angle_variables[from_bus, :]
        bus_angle_to = bus_angle_variables[to_bus, :]
        @assert inv_x > 0.0
        for t in time_steps
            branch_flow[name, t] = JuMP.@constraint(
                jump_model,
                flow_variables_[t] ==
                inv_x * (bus_angle_from[t] - bus_angle_to[t] + angle_variables_[t])
            )
        end
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{T},
    device_model::DeviceModel{T, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    if get_use_slacks(device_model)
        variable_up = get_variable(container, FlowActivePowerSlackUpperBound(), T)
        # Use device names because there might be a network reduction
        for name in axes(variable_up, 1)
            for t in get_time_steps(container)
                add_to_objective_invariant_expression!(
                    container,
                    variable_up[name, t] * CONSTRAINT_VIOLATION_SLACK_COST,
                )
            end
        end
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{T},
    device_model::DeviceModel{T, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ACBranch}
    if get_use_slacks(device_model)
        variable_up = get_variable(container, FlowActivePowerSlackUpperBound(), T)
        variable_dn = get_variable(container, FlowActivePowerSlackLowerBound(), T)
        # Use device names because there might be a network reduction
        for name in axes(variable_up, 1)
            for t in get_time_steps(container)
                add_to_objective_invariant_expression!(
                    container,
                    (variable_dn[name, t] + variable_up[name, t]) *
                    CONSTRAINT_VIOLATION_SLACK_COST,
                )
            end
        end
    end
    return
end
