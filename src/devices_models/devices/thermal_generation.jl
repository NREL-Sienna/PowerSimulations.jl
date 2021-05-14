#! format: off

########################### Thermal Generation Models ######################################
abstract type AbstractThermalFormulation <: AbstractDeviceFormulation end
abstract type AbstractThermalDispatchFormulation <: AbstractThermalFormulation end
abstract type AbstractThermalUnitCommitment <: AbstractThermalFormulation end

abstract type AbstractStandardUnitCommitment <: AbstractThermalUnitCommitment end
abstract type AbstractCompactUnitCommitment <: AbstractThermalUnitCommitment end

struct ThermalBasicUnitCommitment <: AbstractStandardUnitCommitment end
struct ThermalStandardUnitCommitment <: AbstractStandardUnitCommitment end
struct ThermalDispatch <: AbstractThermalDispatchFormulation end
struct ThermalRampLimited <: AbstractThermalDispatchFormulation end
struct ThermalDispatchNoMin <: AbstractThermalDispatchFormulation end

struct ThermalMultiStartUnitCommitment <: AbstractCompactUnitCommitment end
struct ThermalCompactUnitCommitment <: AbstractCompactUnitCommitment end
struct ThermalCompactDispatch <: AbstractThermalDispatchFormulation end

get_variable_sign(_, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = 1.0
############## ActivePowerVariable, ThermalGen ####################
get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = false
get_variable_expression_name(::ActivePowerVariable, ::Type{<:PSY.ThermalGen}) = :nodal_balance_active
get_variable_initial_value(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power(d)
get_variable_initial_value(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = max(0.0, PSY.get_active_power(d) - PSY.get_active_power_limits(d).min)

get_variable_lower_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).min
get_variable_lower_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).max
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = PSY.get_active_power_limits(d).max - PSY.get_active_power_limits(d).min

############## ReactivePowerVariable, ThermalGen ####################
get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = false
get_variable_expression_name(::ReactivePowerVariable, ::Type{<:PSY.ThermalGen}) = :nodal_balance_reactive

get_variable_initial_value(::ReactivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_reactive_power(d)

get_variable_lower_bound(::ReactivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).max

############## OnVariable, ThermalGen ####################
get_variable_binary(::OnVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = true
get_variable_initial_value(::OnVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_status(d) ? 1.0 : 0.0

############## StopVariable, ThermalGen ####################
get_variable_binary(::StopVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = true
get_variable_lower_bound(::StopVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 0.0
get_variable_upper_bound(::StopVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 1.0

############## StartVariable, ThermalGen ####################
get_variable_binary(::StartVariable, d::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = true
get_variable_lower_bound(::StartVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 0.0
get_variable_upper_bound(::StartVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 1.0

############## ColdStartVariable, WarmStartVariable, HotStartVariable ############
get_variable_binary(::Union{ColdStartVariable, WarmStartVariable, HotStartVariable}, ::Type{PSY.ThermalMultiStart}, ::AbstractThermalFormulation) = true


#! format: on

######## CONSTRAINTS ############

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{<:VariableType},
    ::Type{T},
    ::Type{<:AbstractThermalFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::SemiContinuousFF,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return DeviceRangeConstraintSpec()
end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractThermalDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractThermalUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            bin_variable_names = [make_variable_name(OnVariable, T)],
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            limits_func = x -> (min = 0.0, max = PSY.get_active_power_limits(x).max),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
        custom_optimization_container_func = custom_active_power_constraints!,
    )
end

function custom_active_power_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{<:ThermalDispatchNoMin},
) where {T <: PSY.ThermalGen}
    var_key = make_variable_name(ActivePowerVariable, T)
    variable = get_variable(optimization_container, var_key)
    # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
    for v in variable
        if JuMP.has_lower_bound(v)
            JuMP.set_lower_bound(v, 0.0)
        end
    end
end

"""
This function adds the active power limits of generators. Constraint (17) & (18) from PGLIB
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:ThermalMultiStartUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalMultiStart}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            limits_func = x -> (
                min = 0.0,
                max = PSY.get_active_power_limits(x).max -
                      PSY.get_active_power_limits(x).min,
            ),
            bin_variable_names = [
                make_variable_name(OnVariable, T),
                make_variable_name(StartVariable, T),
                make_variable_name(StopVariable, T),
            ],
            constraint_func = device_multistart_range!,
            constraint_struct = DeviceMultiStartRangeConstraintsInfo,
            lag_limits_func = PSY.get_power_trajectory,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractCompactUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            limits_func = x -> (
                min = PSY.get_active_power_limits(x).min,
                max = PSY.get_active_power_limits(x).max,
            ),
            bin_variable_names = [
                make_variable_name(OnVariable, T),
                make_variable_name(StartVariable, T),
                make_variable_name(StopVariable, T),
            ],
            constraint_func = device_multistart_range!,
            constraint_struct = DeviceMultiStartRangeConstraintsInfo,
            lag_limits_func = x -> (
                startup = PSY.get_active_power_limits(x).max,
                shutdown = PSY.get_active_power_limits(x).max,
            ),
        ),
    )
end

function _get_data_for_range_ic(
    initial_conditions_power::Vector{InitialCondition},
    initial_conditions_status::Vector{InitialCondition},
)
    lenght_devices_power = length(initial_conditions_power)
    lenght_devices_status = length(initial_conditions_status)
    @assert lenght_devices_power == lenght_devices_status
    ini_conds = Matrix{InitialCondition}(undef, lenght_devices_power, 2)
    idx = 0
    for (ix, ic) in enumerate(initial_conditions_power)
        g = ic.device
        @assert g == initial_conditions_status[ix].device
        idx += 1
        ini_conds[idx, 1] = ic
        ini_conds[idx, 2] = initial_conditions_status[ix]
    end
    return ini_conds
end

"""
This function adds range constraint for the first time period. Constraint (10) from PGLIB formulation
"""
function initial_range_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: PSY.ThermalMultiStart,
    D <: AbstractCompactUnitCommitment,
    S <: PM.AbstractPowerModel,
}
    key_power = ICKey(DevicePower, T)
    key_status = ICKey(DeviceStatus, T)
    initial_conditions_power = get_initial_conditions(optimization_container, key_power)
    initial_conditions_status = get_initial_conditions(optimization_container, key_status)
    ini_conds = _get_data_for_range_ic(initial_conditions_power, initial_conditions_status)

    constraint_data = Vector{DeviceMultiStartRangeConstraintsInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = PSY.get_active_power_limits(d)
        name = PSY.get_name(d)
        @assert name == PSY.get_name(ini_conds[ix, 1].device)
        lag_ramp_limits = PSY.get_power_trajectory(d)
        range_data = DeviceMultiStartRangeConstraintsInfo(name, limits, lag_ramp_limits)
        add_device_services!(range_data, d, model)
        constraint_data[ix] = range_data
    end

    if !isempty(ini_conds)
        device_multistart_range_ic!(
            optimization_container,
            constraint_data,
            ini_conds,
            make_constraint_name(ACTIVE_RANGE_IC, T),
            make_variable_name(StopVariable, T),
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractThermalDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RangeConstraint,
                ReactivePowerVariable,
                T,
            ),
            variable_name = make_variable_name(ReactivePowerVariable, T),
            limits_func = x -> PSY.get_reactive_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractThermalDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::SemiContinuousFF,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return DeviceRangeConstraintSpec()
end

"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractThermalUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RangeConstraint,
                ReactivePowerVariable,
                T,
            ),
            variable_name = make_variable_name(ReactivePowerVariable, T),
            bin_variable_names = [make_variable_name(OnVariable, T)],
            limits_func = x -> PSY.get_reactive_power_limits(x),
            constraint_func = device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractThermalUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::SemiContinuousFF,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return DeviceRangeConstraintSpec()
end

### Constraints for Thermal Generation without commitment variables ####
"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints!(
    optimization_container::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalUnitCommitment,
    S <: PM.AbstractPowerModel,
}
    device_commitment!(
        optimization_container,
        get_initial_conditions(optimization_container, ICKey(DeviceStatus, T)),
        make_constraint_name(COMMITMENT, T),
        (
            make_variable_name(StartVariable, T),
            make_variable_name(StopVariable, T),
            make_variable_name(OnVariable, T),
        ),
    )
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    formulation::AbstractThermalUnitCommitment,
) where {T <: PSY.ThermalGen}
    status_initial_condition!(optimization_container, devices, formulation)
    output_initial_condition!(optimization_container, devices, formulation)
    duration_initial_condition!(optimization_container, devices, formulation)
    return
end

function initial_conditions!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    formulation::ThermalBasicUnitCommitment,
) where {T <: PSY.ThermalGen}
    status_initial_condition!(optimization_container, devices, formulation)
    output_initial_condition!(optimization_container, devices, formulation)
    return
end

function initial_conditions!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    formulation::AbstractThermalDispatchFormulation,
) where {T <: PSY.ThermalGen}
    output_initial_condition!(optimization_container, devices, formulation)
    return
end

######################### Initialize Functions for ThermalGen ##############################
"""
Status Init is always calculated based on the Power Output of the device
This is to make it easier to calculate when the previous model doesn't
contain binaries. For instance, looking back on an ED model to find the
IC of the UC model
"""
function status_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation}
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        OnVariable(),
        ICKey(DeviceStatus, T),
        _make_initial_condition_active_power,
        _get_variable_initial_value,
    )

    return
end

function status_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.ThermalGen, D <: AbstractCompactUnitCommitment}
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        OnVariable(),
        ICKey(DeviceStatus, T),
        _make_initial_condition_status,
        _get_variable_initial_value,
    )

    return
end

function output_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation}
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        ActivePowerVariable(),
        ICKey(DevicePower, T),
        _make_initial_condition_active_power,
        _get_variable_initial_value,
    )
    return
end

function duration_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation}
    for key in (ICKey(InitialTimeDurationOn, T), ICKey(InitialTimeDurationOff, T))
        _make_initial_conditions!(
            optimization_container,
            devices,
            D(),
            nothing,
            key,
            _make_initial_condition_active_power,
            _get_variable_initial_value,
            TimeStatusChange,
        )
    end

    return
end

function duration_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.ThermalGen, D <: AbstractCompactUnitCommitment}
    for key in (ICKey(InitialTimeDurationOn, T), ICKey(InitialTimeDurationOff, T))
        _make_initial_conditions!(
            optimization_container,
            devices,
            D(),
            nothing,
            key,
            _make_initial_condition_status,
            _get_variable_initial_value,
            TimeStatusChange,
        )
    end

    return
end

############################ Auxiliary Variables Calculation ################################
function calculate_aux_variable_value!(
    optimization_container::OptimizationContainer,
    key::AuxVarKey{TimeDurationOn, T},
    ::PSY.System,
) where {T <: PSY.ThermalGen}
    on_var_results = get_variable(optimization_container, OnVariable, T)
    aux_var_container = get_aux_variables(optimization_container)[key]
    ini_cond = get_initial_conditions(optimization_container, InitialTimeDurationOn, T)

    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    minutes_per_period = Dates.value(Dates.Minute(resolution))

    for ix in eachindex(JuMP.axes(aux_var_container)[1])
        @assert JuMP.axes(aux_var_container)[1][ix] == JuMP.axes(on_var_results)[1][ix]
        @assert JuMP.axes(aux_var_container)[1][ix] == get_device_name(ini_cond[ix])
        on_var = JuMP.value.(on_var_results.data[ix, :])
        ini_cond_value = get_condition(ini_cond[ix])
        aux_var_container.data[ix, :] .= ini_cond_value
        sum_on_var = sum(on_var)
        if sum_on_var == time_steps[end] # Unit was always on
            aux_var_container.data[ix, :] += time_steps * minutes_per_period
        elseif sum_on_var == 0.0 # Unit was always off
            aux_var_container.data[ix, :] .= 0.0
        else
            previous_condition = ini_cond_value
            for (t, v) in enumerate(on_var)
                if v < 0.99 # Unit turn off
                    time_value = 0.0
                elseif isapprox(v, 1.0) # Unit is on
                    time_value = previous_condition + 1.0
                else
                    @assert false
                end
                previous_condition = aux_var_container.data[ix, t] = time_value
            end
        end
    end

    return
end

function calculate_aux_variable_value!(
    optimization_container::OptimizationContainer,
    key::AuxVarKey{TimeDurationOff, T},
    ::PSY.System,
) where {T <: PSY.ThermalGen}
    on_var_results = get_variable(optimization_container, OnVariable, T)
    aux_var_container = get_aux_variables(optimization_container)[key]
    ini_cond = get_initial_conditions(optimization_container, InitialTimeDurationOff, T)

    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    minutes_per_period = Dates.value(Dates.Minute(resolution))

    for ix in eachindex(JuMP.axes(aux_var_container)[1])
        @assert JuMP.axes(aux_var_container)[1][ix] == JuMP.axes(on_var_results)[1][ix]
        @assert JuMP.axes(aux_var_container)[1][ix] == get_device_name(ini_cond[ix])
        on_var = JuMP.value.(on_var_results.data[ix, :])
        ini_cond_value = get_condition(ini_cond[ix])
        aux_var_container.data[ix, :] .= ini_cond_value
        sum_on_var = sum(on_var)
        if sum_on_var == time_steps[end] # Unit was always on
            aux_var_container.data[ix, :] .= 0.0
        elseif sum_on_var == 0.0 # Unit was always off
            aux_var_container.data[ix, :] += time_steps * minutes_per_period
        else
            previous_condition = ini_cond_value
            for (t, v) in enumerate(on_var)
                if v < 0.99 # Unit turn off
                    time_value = previous_condition + 1.0
                elseif isapprox(v, 1.0) # Unit is on
                    time_value = 0.0
                end
                previous_condition = aux_var_container.data[ix, t] = time_value
            end
        end
    end

    return
end
########################### Ramp/Rate of Change Constraints ################################
"""
This function gets the data for the generators for ramping constraints of thermal generators
"""
function _get_data_for_rocc(
    optimization_container::OptimizationContainer,
    ::Type{T},
) where {T <: PSY.ThermalGen}
    resolution = model_resolution(optimization_container)
    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        @warn("Not all formulations support under 1-minute resolutions. Exercise caution.")
        minutes_per_period = Dates.value(Dates.Second(resolution)) / 60
    end

    initial_conditions_power =
        get_initial_conditions(optimization_container, DevicePower, T)
    lenght_devices_power = length(initial_conditions_power)
    data = Vector{DeviceRampConstraintInfo}(undef, lenght_devices_power)
    idx = 0
    for ic in initial_conditions_power
        g = ic.device
        name = PSY.get_name(g)
        ramp_limits = PSY.get_ramp_limits(g)
        if !(ramp_limits === nothing)
            p_lims = PSY.get_active_power_limits(g)
            max_rate = abs(p_lims.min - p_lims.max) / minutes_per_period
            if (ramp_limits.up >= max_rate) & (ramp_limits.down >= max_rate)
                @debug "Generator $(name) has a nonbinding ramp limits. Constraints Skipped"
                continue
            else
                idx += 1
            end
            ramp = (
                up = ramp_limits.up * minutes_per_period,
                down = ramp_limits.down * minutes_per_period,
            )
            data[idx] = DeviceRampConstraintInfo(name, p_lims, ic, ramp)
        end
    end
    if idx < lenght_devices_power
        deleteat!(data, (idx + 1):lenght_devices_power)
    end
    return data
end

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints!(
    optimization_container::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalUnitCommitment,
    S <: PM.AbstractPowerModel,
}
    data = _get_data_for_rocc(optimization_container, T)
    if !isempty(data)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        for r in data
            add_device_services!(r, r.ic_power.device, model)
        end
        device_mixedinteger_rateofchange!(
            optimization_container,
            data,
            make_constraint_name(RAMP, T),
            (
                make_variable_name(ActivePowerVariable, T),
                make_variable_name(StartVariable, T),
                make_variable_name(StopVariable, T),
            ),
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

function ramp_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    data = _get_data_for_rocc(optimization_container, T)
    if !isempty(data)
        for r in data
            add_device_services!(r, r.ic_power.device, model)
        end
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_linear_rateofchange!(
            optimization_container,
            data,
            make_constraint_name(RAMP, T),
            make_variable_name(ActivePowerVariable, T),
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

function ramp_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(optimization_container)
    data = _get_data_for_rocc(optimization_container, PSY.ThermalMultiStart)

    # TODO: Refactor this to a cleaner format that doesn't require passing the device and rate_data this way
    for r in data
        add_device_services!(r, r.ic_power.device, model)
    end
    if !isempty(data)
        device_multistart_rateofchange!(
            optimization_container,
            data,
            make_constraint_name(RAMP, PSY.ThermalMultiStart),
            make_variable_name(ActivePowerVariable, PSY.ThermalMultiStart),
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

########################### start up trajectory constraints ######################################

function _convert_hours_to_timesteps(
    start_times_hr::StartUpStages,
    resolution::Dates.TimePeriod,
)
    _start_times_ts = (
        round((hr * MINUTES_IN_HOUR) / Dates.value(Dates.Minute(resolution)), RoundUp) for
        hr in start_times_hr
    )
    start_times_ts = StartUpStages(_start_times_ts)
    return start_times_ts
end

@doc raw"""
    turbine_temperature(optimization_container::OptimizationContainer,
                            startup_data::Vector{DeviceStartUpConstraintInfo},
                            cons_name::Symbol,
                            var_stop::Symbol,
                            var_starts::Tuple{Symbol, Symbol})

Constructs contraints for different types of starts based on generator down-time

# Equations
for t in time_limits[s+1]:T

``` var_starts[name, s, t] <= sum( var_stop[name, t-i] for i in time_limits[s]:(time_limits[s+1]-1)  ```

# LaTeX

``  δ^{s}(t)  \leq \sum_{i=TS^{s}_{g}}^{TS^{s+1}_{g}} x^{stop}(t-i) ``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* rate_data::Vector{DeviceStartUpConstraintInfo},
* cons_name::Symbol : name of the constraint
* var_stop::Symbol : name of the stop variable
* var_starts::Tuple{Symbol, Symbol} : the names of the different start variables
"""
function turbine_temperature(
    optimization_container::OptimizationContainer,
    startup_data::Vector{DeviceStartUpConstraintInfo},
    cons_name::Symbol,
    var_stop::Symbol,
    var_starts::Tuple{Symbol, Symbol},
)
    time_steps = model_time_steps(optimization_container)
    start_vars = [
        get_variable(optimization_container, var_starts[1]),
        get_variable(optimization_container, var_starts[2]),
    ]
    varstop = get_variable(optimization_container, var_stop)

    hot_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "hot")
    warm_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "warm")

    names = [get_component_name(st) for st in startup_data]

    con = [
        add_cons_container!(
            optimization_container,
            hot_name,
            names,
            time_steps;
            sparse = true,
        ),
        add_cons_container!(
            optimization_container,
            warm_name,
            names,
            time_steps;
            sparse = true,
        ),
    ]

    for t in time_steps, st in startup_data
        for ix in 1:(st.startup_types - 1)
            if t >= st.time_limits[ix + 1]
                name = get_component_name(st)
                con[ix][name, t] = JuMP.@constraint(
                    optimization_container.JuMPmodel,
                    start_vars[ix][name, t] <= sum(
                        varstop[name, t - i] for i in UnitRange{Int}(
                            Int(st.time_limits[ix]),
                            Int(st.time_limits[ix + 1] - 1),
                        )
                    )
                )
            end
        end
    end
    return
end

@doc raw"""
    device_start_type_constraint(optimization_container::OptimizationContainer,
                            data::Vector{DeviceStartTypesConstraintInfo},
                            cons_name::Symbol,
                            var_start::Symbol,
                            var_names::Tuple{Symbol, Symbol, Symbol},)

Constructs contraints that restricts devices to one type of start at a time

# Equations

``` sum(var_starts[name, s, t] for s in starts) = var_start[name, t]  ```

# LaTeX

``  \sum^{S_g}_{s=1} δ^{s}(t)  \eq  x^{start}(t) ``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* data::Vector{DeviceStartTypesConstraintInfo},
* cons_name::Symbol : name of the constraint
* var_start::Symbol : name of the startup variable
* var_starts::Tuple{Symbol, Symbol} : the names of the different start variables
"""
function device_start_type_constraint(
    optimization_container::OptimizationContainer,
    data::Vector{DeviceStartTypesConstraintInfo},
    cons_name::Symbol,
    var_start::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(optimization_container)
    varstart = get_variable(optimization_container, var_start)
    start_vars = [
        get_variable(optimization_container, var_names[1]),
        get_variable(optimization_container, var_names[2]),
        get_variable(optimization_container, var_names[3]),
    ]

    set_name = [get_component_name(d) for d in data]
    con = add_cons_container!(optimization_container, cons_name, set_name, time_steps)

    for t in time_steps, d in data
        name = get_component_name(d)
        con[name, t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            varstart[name, t] == sum(start_vars[ix][name, t] for ix in 1:(d.startup_types))
        )
    end
    return
end

@doc raw"""
    device_startup_initial_condition(optimization_container::OptimizationContainer,
                            data::Vector{DeviceStartUpConstraintInfo},
                            initial_conditions::Vector{InitialCondition},
                            cons_name::Symbol,
                            var_names::Tuple{Symbol, Symbol},
                            bin_name::Symbol,)

Constructs contraints that restricts devices to one type of start at a time

# Equations
ub:
``` (time_limits[st+1]-1)*δ^{s}(t) + (1 - δ^{s}(t)) * M_VALUE >= sum(1-varbin[name, i]) for i in 1:t) + initial_condition_offtime  ```
lb:
``` (time_limits[st]-1)*δ^{s}(t) =< sum(1-varbin[name, i]) for i in 1:t) + initial_condition_offtime  ```

# LaTeX

`` TS^{s+1}_{g} δ^{s}(t) + (1-δ^{s}(t)) M_VALUE   \geq  \sum^{t}_{i=1} x^{status}(i)  +  DT_{g}^{0}  \forall t in \{1, \ldots,  TS^{s+1}_{g}``

`` TS^{s}_{g} δ^{s}(t) \leq  \sum^{t}_{i=1} x^{status}(i)  +  DT_{g}^{0}  \forall t in \{1, \ldots,  TS^{s+1}_{g}``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* data::Vector{DeviceStartTypesConstraintInfo},
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol} : the names of the different start variables
* bin_name::Symbol : name of the status variable
"""
function device_startup_initial_condition(
    optimization_container::OptimizationContainer,
    data::Vector{DeviceStartUpConstraintInfo},
    initial_conditions::Vector{InitialCondition},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
    bin_name::Symbol,
)
    time_steps = model_time_steps(optimization_container)

    set_name = [get_device_name(ic) for ic in initial_conditions]
    up_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    down_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    varbin = get_variable(optimization_container, bin_name)
    varstarts = [
        get_variable(optimization_container, var_names[1]),
        get_variable(optimization_container, var_names[2]),
    ]

    con_ub = add_cons_container!(
        optimization_container,
        up_name,
        set_name,
        time_steps,
        1:(MAX_START_STAGES - 1);
        sparse = true,
    )
    con_lb = add_cons_container!(
        optimization_container,
        down_name,
        set_name,
        time_steps,
        1:(MAX_START_STAGES - 1);
        sparse = true,
    )

    for t in time_steps, (ix, d) in enumerate(data)
        name = get_component_name(d)
        ic = initial_conditions[ix]
        for st in 1:(d.startup_types - 1)
            var = varstarts[st]
            if t < (d.time_limits[st + 1] - 1)
                con_ub[name, t, st] = JuMP.@constraint(
                    optimization_container.JuMPmodel,
                    (d.time_limits[st + 1] - 1) * var[name, t] +
                    (1 - var[name, t]) * M_VALUE >=
                    sum((1 - varbin[name, i]) for i in 1:t) + ic.value
                )
                con_lb[name, t, st] = JuMP.@constraint(
                    optimization_container.JuMPmodel,
                    d.time_limits[st] * var[name, t] <=
                    sum((1 - varbin[name, i]) for i in 1:t) + ic.value
                )
            end
        end
    end
    return
end

"""
This function creates the contraints for different types of starts based on generator down-time
"""
function startup_time_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    resolution = model_resolution(optimization_container)
    lenght_devices = length(devices)
    start_time_params = Vector{DeviceStartUpConstraintInfo}(undef, lenght_devices)
    for (ix, g) in enumerate(devices)
        start_times_hr = PSY.get_start_time_limits(g)
        start_types = PSY.get_start_types(g)
        name = PSY.get_name(g)
        start_times_ts = _convert_hours_to_timesteps(start_times_hr, resolution)
        start_time_params[ix] =
            DeviceStartUpConstraintInfo(name, start_times_ts, start_types)
    end

    turbine_temperature(
        optimization_container,
        start_time_params,
        make_constraint_name(STARTUP_TIMELIMIT, PSY.ThermalMultiStart),
        make_variable_name(StopVariable, PSY.ThermalMultiStart),
        (
            make_variable_name(HotStartVariable, PSY.ThermalMultiStart),
            make_variable_name(WarmStartVariable, PSY.ThermalMultiStart),
        ),
    )
    return
end

"""
This function creates constraints to select a single type of startup based on off-time
"""
function startup_type_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    constraint_data = Vector{DeviceStartTypesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        start_types = PSY.get_start_types(d)
        range_data = DeviceStartTypesConstraintInfo(name, start_types)
        constraint_data[ix] = range_data
    end

    device_start_type_constraint(
        optimization_container,
        constraint_data,
        make_constraint_name(START_TYPE, PSY.ThermalMultiStart),
        make_variable_name(START, PSY.ThermalMultiStart),
        (
            make_variable_name(HotStartVariable, PSY.ThermalMultiStart),
            make_variable_name(WarmStartVariable, PSY.ThermalMultiStart),
            make_variable_name(ColdStartVariable, PSY.ThermalMultiStart),
        ),
    )
    return
end

"""
This function gets the data for startup initial condition
"""
function _get_data_startup_ic(
    initial_conditions::Vector{InitialCondition},
    resolution::Dates.TimePeriod,
)
    lenght_devices = length(initial_conditions)
    data = Vector{DeviceStartUpConstraintInfo}(undef, lenght_devices)
    idx = 0
    for ic in initial_conditions
        g = ic.device
        start_types = PSY.get_start_types(g)
        start_times_hr = PSY.get_start_time_limits(g)
        if start_types > 1
            idx = +1
            name = PSY.get_name(g)
            start_times_ts = _convert_hours_to_timesteps(start_times_hr, resolution)
            data[idx] = DeviceStartUpConstraintInfo(name, start_times_ts, start_types)
        end
    end
    if idx < lenght_devices
        deleteat!(data, (idx + 1):lenght_devices)
    end

    return data
end

"""
This function creates the initial conditions for multi-start devices
"""
function startup_initial_condition_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    resolution = model_resolution(optimization_container)
    key_off = ICKey(InitialTimeDurationOff, PSY.ThermalMultiStart)
    initial_conditions_offtime = get_initial_conditions(optimization_container, key_off)
    constraint_data = _get_data_startup_ic(initial_conditions_offtime, resolution)

    device_startup_initial_condition(
        optimization_container,
        constraint_data,
        initial_conditions_offtime,
        make_constraint_name(STARTUP_INITIAL_CONDITION, PSY.ThermalMultiStart),
        (
            make_variable_name(HotStartVariable, PSY.ThermalMultiStart),
            make_variable_name(WarmStartVariable, PSY.ThermalMultiStart),
        ),
        make_variable_name(OnVariable, PSY.ThermalMultiStart),
    )
    return
end

"""
This function creates constraints that keep must run devices online
"""
function must_run_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(optimization_container)
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = ones(time_steps[end])
        timeseries_data =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_must_run(x), ts_vector)
        constraint_infos[ix] = timeseries_data
    end
    ts_inputs = TimeSeriesConstraintSpecInternal(
        constraint_infos,
        make_constraint_name(MUST_RUN, PSY.ThermalMultiStart),
        make_variable_name(OnVariable, PSY.ThermalMultiStart),
        nothing,
        nothing,
        nothing,
    )

    device_timeseries_lb!(optimization_container, ts_inputs)
    return
end

########################### time duration constraints ######################################
"""
If the fraction of hours that a generator has a duration constraint is less than
the fraction of hours that a single time_step represents then it is not binding.
"""
function _get_data_for_tdc(
    initial_conditions_on::Vector{InitialCondition},
    initial_conditions_off::Vector{InitialCondition},
    resolution::Dates.TimePeriod,
)
    steps_per_hour = 60 / Dates.value(Dates.Minute(resolution))
    fraction_of_hour = 1 / steps_per_hour
    lenght_devices_on = length(initial_conditions_on)
    lenght_devices_off = length(initial_conditions_off)
    @assert lenght_devices_off == lenght_devices_on
    time_params = Vector{UpDown}(undef, lenght_devices_on)
    ini_conds = Matrix{InitialCondition}(undef, lenght_devices_on, 2)
    idx = 0
    for (ix, ic) in enumerate(initial_conditions_on)
        g = ic.device
        @assert g == initial_conditions_off[ix].device
        time_limits = PSY.get_time_limits(g)
        name = PSY.get_name(g)
        if !(time_limits === nothing)
            if (time_limits.up <= fraction_of_hour) & (time_limits.down <= fraction_of_hour)
                @debug "Generator $(name) has a nonbinding time limits. Constraints Skipped"
                continue
            else
                idx += 1
            end
            ini_conds[idx, 1] = ic
            ini_conds[idx, 2] = initial_conditions_off[ix]
            up_val = round(time_limits.up * steps_per_hour, RoundUp)
            down_val = round(time_limits.down * steps_per_hour, RoundUp)
            time_params[idx] = time_params[idx] = (up = up_val, down = down_val)
        end
    end
    if idx < lenght_devices_on
        ini_conds = ini_conds[1:idx, :]
        deleteat!(time_params, (idx + 1):lenght_devices_on)
    end
    return ini_conds, time_params
end

function time_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalUnitCommitment,
    S <: PM.AbstractPowerModel,
}
    parameters = model_has_parameters(optimization_container)
    resolution = model_resolution(optimization_container)
    initial_conditions_on =
        get_initial_conditions(optimization_container, ICKey(InitialTimeDurationOn, T))
    initial_conditions_off =
        get_initial_conditions(optimization_container, ICKey(InitialTimeDurationOff, T))
    ini_conds, time_params =
        _get_data_for_tdc(initial_conditions_on, initial_conditions_off, resolution)
    if !(isempty(ini_conds))
        if parameters
            device_duration_parameters!(
                optimization_container,
                time_params,
                ini_conds,
                make_constraint_name(DURATION, T),
                (
                    make_variable_name(OnVariable, T),
                    make_variable_name(StartVariable, T),
                    make_variable_name(StopVariable, T),
                ),
            )
        else
            device_duration_retrospective!(
                optimization_container,
                time_params,
                ini_conds,
                make_constraint_name(DURATION, T),
                (
                    make_variable_name(OnVariable, T),
                    make_variable_name(StartVariable, T),
                    make_variable_name(StopVariable, T),
                ),
            )
        end
    else
        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"
    end
    return
end

function time_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    parameters = model_has_parameters(optimization_container)
    resolution = model_resolution(optimization_container)
    initial_conditions_on =
        get_initial_conditions(optimization_container, ICKey(InitialTimeDurationOn, T))
    initial_conditions_off =
        get_initial_conditions(optimization_container, ICKey(InitialTimeDurationOff, T))
    ini_conds, time_params =
        _get_data_for_tdc(initial_conditions_on, initial_conditions_off, resolution)
    if !(isempty(ini_conds))
        if parameters
            device_duration_parameters!(
                optimization_container,
                time_params,
                ini_conds,
                make_constraint_name(DURATION, T),
                (
                    make_variable_name(OnVariable, T),
                    make_variable_name(StartVariable, T),
                    make_variable_name(StopVariable, T),
                ),
            )
        else
            device_duration_compact_retrospective!(
                optimization_container,
                time_params,
                ini_conds,
                make_constraint_name(DURATION, T),
                (
                    make_variable_name(OnVariable, T),
                    make_variable_name(StartVariable, T),
                    make_variable_name(StopVariable, T),
                ),
            )
        end
    else
        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"
    end
    return
end

########################### Cost Function Calls#############################################
# These functions are custom implementations of the cost data. In the file cost_functions.jl there are default implementations. Define these only if needed.

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    optimization_container::OptimizationContainer,
) where {T <: PSY.ThermalGen, U <: AbstractThermalUnitCommitment}
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(optimization_container, T),
        has_status_parameter = has_on_parameter(optimization_container, T),
        variable_cost = PSY.get_variable,
        start_up_cost = PSY.get_start_up,
        shut_down_cost = PSY.get_shut_down,
        fixed_cost = PSY.get_fixed,
        sos_status = SOSStatusVariable.VARIABLE,
    )
end

function AddCostSpec(
    ::Type{PSY.ThermalMultiStart},
    ::Type{U},
    optimization_container::OptimizationContainer,
) where {U <: AbstractStandardUnitCommitment}
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = PSY.ThermalMultiStart,
        has_status_variable = has_on_variable(
            optimization_container,
            PSY.ThermalMultiStart,
        ),
        has_status_parameter = has_on_parameter(
            optimization_container,
            PSY.ThermalMultiStart,
        ),
        variable_cost = PSY.get_variable,
        start_up_cost = x -> getfield(PSY.get_start_up(x), :cold),
        shut_down_cost = PSY.get_shut_down,
        fixed_cost = PSY.get_fixed,
        sos_status = SOSStatusVariable.VARIABLE,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    optimization_container::OptimizationContainer,
) where {T <: PSY.ThermalGen, U <: AbstractThermalDispatchFormulation}
    if has_on_parameter(optimization_container, T)
        sos_status = SOSStatusVariable.PARAMETER
    else
        sos_status = SOSStatusVariable.NO_VARIABLE
    end

    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(optimization_container, T),
        has_status_parameter = has_on_parameter(optimization_container, T),
        variable_cost = PSY.get_variable,
        fixed_cost = PSY.get_fixed,
        sos_status = sos_status,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    optimization_container::OptimizationContainer,
) where {T <: PSY.ThermalGen, U <: AbstractCompactUnitCommitment}
    fixed_cost_func = x -> PSY.get_fixed(x) + PSY.get_no_load(x)
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(optimization_container, T),
        has_status_parameter = has_on_parameter(optimization_container, T),
        variable_cost = _get_compact_varcost,
        shut_down_cost = PSY.get_shut_down,
        start_up_cost = PSY.get_start_up,
        fixed_cost = fixed_cost_func,
        sos_status = SOSStatusVariable.VARIABLE,
        uses_compact_power = true,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{ThermalCompactDispatch},
    optimization_container::OptimizationContainer,
) where {T <: PSY.ThermalGen}
    if has_on_parameter(optimization_container, T)
        sos_status = SOSStatusVariable.PARAMETER
    else
        sos_status = SOSStatusVariable.NO_VARIABLE
    end
    fixed_cost_func = x -> PSY.get_fixed(x) + PSY.get_no_load(x)
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(optimization_container, T),
        has_status_parameter = has_on_parameter(optimization_container, T),
        variable_cost = _get_compact_varcost,
        fixed_cost = fixed_cost_func,
        sos_status = sos_status,
        uses_compact_power = true,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    optimization_container::OptimizationContainer,
) where {T <: PSY.ThermalGen, U <: ThermalMultiStartUnitCommitment}
    fixed_cost_func = x -> PSY.get_fixed(x) + PSY.get_no_load(x)
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(optimization_container, T),
        has_status_parameter = has_on_parameter(optimization_container, T),
        variable_cost = _get_compact_varcost,
        start_up_cost = PSY.get_start_up,
        shut_down_cost = PSY.get_shut_down,
        fixed_cost = fixed_cost_func,
        sos_status = SOSStatusVariable.VARIABLE,
        has_multistart_variables = true,
        uses_compact_power = true,
    )
end

function PSY.get_no_load(cost::Union{PSY.ThreePartCost, PSY.TwoPartCost})
    _, no_load_cost = _convert_variable_cost(PSY.get_variable(cost))
    return no_load_cost
end

function _get_compact_varcost(cost)
    return PSY.get_variable(cost)
end

function _get_compact_varcost(cost::Union{PSY.ThreePartCost, PSY.TwoPartCost})
    var_cost, _ = _convert_variable_cost(PSY.get_variable(cost))
    return var_cost
end

function _convert_variable_cost(var_cost::PSY.VariableCost)
    return var_cost, 0.0
end

function _convert_variable_cost(var_cost::PSY.VariableCost{Float64})
    return var_cost, var_cost
end

function _convert_variable_cost(variable_cost::PSY.VariableCost{Vector{NTuple{2, Float64}}})
    var_cost = PSY.get_cost(variable_cost)
    no_load_cost, p_min = var_cost[1]
    var_cost = PSY.VariableCost([(c - no_load_cost, pp - p_min) for (c, pp) in var_cost])
    return var_cost, no_load_cost
end

"""
Cost function for generators formulated as No-Min
"""
function cost_function!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen}
    no_min_spec = AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(optimization_container, T),
        has_status_parameter = has_on_parameter(optimization_container, T),
        variable_cost = PSY.get_variable,
        fixed_cost = PSY.get_fixed,
    )

    for g in devices
        component_name = PSY.get_name(g)
        op_cost = PSY.get_operation_cost(g)
        cost_component = PSY.get_variable(op_cost)
        if isa(cost_component, PSY.VariableCost{Array{Tuple{Float64, Float64}, 1}})
            @debug "PWL cost function detected for device $(component_name) using ThermalDispatchNoMin"
            slopes = PSY.get_slopes(cost_component)
            if any(slopes .< 0) || !pwlparamcheck(cost_component)
                throw(
                    IS.InvalidValue(
                        "The PWL cost data provided for generator $(PSY.get_name(g)) is not compatible with a No Min Cost.",
                    ),
                )
            end
            if slopes[1] != 0.0
                @debug "PWL has no 0.0 intercept for generator $(PSY.get_name(g))"
                # adds a first intercept a x = 0.0 and Y below the intercept of the first tuple to make convex equivalent
                first_pair = PSY.get_cost(cost_component)[1]
                cost_function_data = deepcopy(cost_component.cost)
                intercept_point = (0.0, first_pair[2] - COST_EPSILON)
                cost_function_data = vcat(intercept_point, cost_function_data)
                @assert slope_convexity_check(slopes)
            else
                cost_function_data = cost_component.cost
            end
            time_steps = model_time_steps(optimization_container)
            for t in time_steps
                pwl_gencost_linear!(
                    optimization_container,
                    no_min_spec,
                    component_name,
                    cost_function_data,
                    t,
                )
            end
        else
            add_to_cost!(optimization_container, no_min_spec, op_cost, g)
        end
    end
    return
end

function cost_function!(
    ::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    ::DeviceModel{PSY.ThermalMultiStart, ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
    ::Union{Nothing, AbstractAffectFeedForward},
)
    error("DispatchNoMin is not compatible with ThermalMultiStart")
end

# TODO: Define for now just for Area Balance and reason about others later. This will
# be needed and useful for PowerFlow
function NodalExpressionSpec(
    ::Type{T},
    ::Type{AreaBalancePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.ThermalGen}
    return NodalExpressionSpec(
        "max_active_power",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_max_active_power(x) : x -> PSY.get_active_power(x),
        1.0,
        T,
    )
end
