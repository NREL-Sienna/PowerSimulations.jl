########################### Thermal Generation Models ######################################
abstract type AbstractThermalFormulation <: AbstractDeviceFormulation end
abstract type AbstractThermalDispatchFormulation <: AbstractThermalFormulation end
abstract type AbstractThermalUnitCommitment <: AbstractThermalFormulation end
struct ThermalBasicUnitCommitment <: AbstractThermalUnitCommitment end
struct ThermalStandardUnitCommitment <: AbstractThermalUnitCommitment end
struct ThermalDispatch <: AbstractThermalDispatchFormulation end
struct ThermalRampLimited <: AbstractThermalDispatchFormulation end
struct ThermalDispatchNoMin <: AbstractThermalDispatchFormulation end
struct ThermalMultiStartUnitCommitment <: AbstractThermalUnitCommitment end

########################### Interfaces ########################################################

get_variable_name(variabletype, d) = error("Not Implemented")
get_variable_binary(pv, d::PSY.Component) = get_variable_binary(pv, typeof(d))
get_variable_binary(pv, t::Type{<:PSY.Component}) = error("`get_variable_binary` must be implemented for $pv and $t")
get_variable_expression_name(_, ::Type{<:PSY.Component}) = nothing
get_variable_sign(_, ::Type{<:PSY.Component}) = 1.0
get_variable_initial_value(_, d::PSY.Component, _) = nothing
get_variable_lower_bound(_, d::PSY.Component, _) = nothing
get_variable_upper_bound(_, d::PSY.Component, _) = nothing

############## ActivePowerVariable, ThermalGen ####################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.ThermalGen}) = false

get_variable_expression_name(::ActivePowerVariable, ::Type{<:PSY.ThermalGen}) = :nodal_balance_active

get_variable_initial_value(pv::ActivePowerVariable, d::PSY.ThermalGen, settings) =
    get_variable_initial_value(pv, d, get_warm_start(settings) ? WarmStartVariable() : ColdStartVariable())
get_variable_initial_value(::ActivePowerVariable, d::PSY.ThermalGen, ::WarmStartVariable) = PSY.get_active_power(d)
get_variable_initial_value(::ActivePowerVariable, d::PSY.ThermalGen, ::ColdStartVariable) = nothing

get_variable_lower_bound(::ActivePowerVariable, d::PSY.ThermalGen, _) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ThermalGen, _) = PSY.get_active_power_limits(d).max

############## ActivePowerVariable, ThermalMultiStart ####################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.ThermalMultiStart}) = false

get_variable_expression_name(::ActivePowerVariable, ::Type{<:PSY.ThermalMultiStart}) = :nodal_balance_active
get_variable_initial_value(pv::ActivePowerVariable, d::PSY.ThermalMultiStart, settings) =
    get_variable_initial_value(pv, d, get_warm_start(settings) ? WarmStartVariable() : ColdStartVariable())
get_variable_initial_value(::ActivePowerVariable, d::PSY.ThermalMultiStart, ::WarmStartVariable) = PSY.get_active_power(d)
get_variable_initial_value(::ActivePowerVariable, d::PSY.ThermalMultiStart, ::ColdStartVariable) = nothing

get_variable_lower_bound(::ActivePowerVariable, d::PSY.ThermalMultiStart, _) = 0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ThermalMultiStart, _) = PSY.get_active_power_limits(d).max

############## ReactivePowerVariable, ThermalGen ####################

get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.ThermalGen}) = false

get_variable_expression_name(::ReactivePowerVariable, ::Type{<:PSY.ThermalGen}) = :nodal_balance_reactive

get_variable_initial_value(pv::ReactivePowerVariable, d::PSY.ThermalGen, settings) =
get_variable_initial_value(pv, d, get_warm_start(settings) ? WarmStartVariable() : ColdStartVariable())
get_variable_initial_value(::ReactivePowerVariable, d::PSY.ThermalGen, ::WarmStartVariable) = PSY.get_active_power(d)
get_variable_initial_value(::ReactivePowerVariable, d::PSY.ThermalGen, ::ColdStartVariable) = nothing

get_variable_lower_bound(::ReactivePowerVariable, d::PSY.ThermalGen, _) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.ThermalGen, _) = PSY.get_active_power_limits(d).max

############## OnVariable, ThermalGen ####################

get_variable_binary(::OnVariable, ::Type{<:PSY.ThermalGen}) = true

get_variable_initial_value(pv::OnVariable, d::PSY.ThermalGen, settings) =
    get_variable_initial_value(pv, d, get_warm_start(settings) ? WarmStartVariable() : ColdStartVariable())
get_variable_initial_value(::OnVariable, d::PSY.ThermalGen, ::WarmStartVariable) = PSY.get_active_power(d) > 0 ? 1.0 : 0.0
get_variable_initial_value(::OnVariable, d::PSY.ThermalGen, ::ColdStartVariable) = nothing

############## StopVariable, ThermalGen ####################

get_variable_binary(::StopVariable, ::Type{<:PSY.ThermalGen}) = true

############## StartVariable, ThermalGen ####################

get_variable_binary(::StartVariable, d::Type{<:PSY.ThermalGen}) = true
get_variable_lower_bound(::StartVariable, d::PSY.ThermalGen, _) = 0.0
get_variable_upper_bound(::StartVariable, d::PSY.ThermalGen, _) = 1.0

############## ColdStartVariable, WarmStartVariable, HotStartVariable ############

get_variable_binary(v::T, d::PSY.ThermalMultiStart) where T <: Union{ColdStartVariable, WarmStartVariable, HotStartVariable} = get_variable_binary(v, typeof(d))
get_variable_binary(::T, ::Type{PSY.ThermalMultiStart}) where T <: Union{ColdStartVariable, WarmStartVariable, HotStartVariable} = true

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

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{<:VariableType},
    ::Type{T},
    ::Type{<:ThermalDispatchNoMin},
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
    ::Type{<:AbstractThermalFormulation},
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
This function adds the active power limits of generators when there are
    no CommitmentVariables
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
        custom_psi_container_func = custom_active_power_constraints!,
    )
end

function custom_active_power_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{<:ThermalDispatchNoMin},
) where {T <: PSY.ThermalGen}
    var_key = make_variable_name(ActivePowerVariable, T)
    variable = get_variable(psi_container, var_key)
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    key_power = ICKey(DevicePower, PSY.ThermalMultiStart)
    key_status = ICKey(DeviceStatus, PSY.ThermalMultiStart)
    initial_conditions_power = get_initial_conditions(psi_container, key_power)
    initial_conditions_status = get_initial_conditions(psi_container, key_status)
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
            psi_container,
            constraint_data,
            ini_conds,
            make_constraint_name(ACTIVE_RANGE_IC, PSY.ThermalMultiStart),
            make_variable_name(StopVariable, PSY.ThermalMultiStart),
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

"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractThermalFormulation},
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

### Constraints for Thermal Generation without commitment variables ####
"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerModel}
    device_commitment!(
        psi_container,
        get_initial_conditions(psi_container, ICKey(DeviceStatus, T)),
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{D},
) where {T <: PSY.ThermalGen, D <: AbstractThermalUnitCommitment}
    status_init(psi_container, devices)
    output_init(psi_container, devices)
    duration_init(psi_container, devices)
    return
end

function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{ThermalBasicUnitCommitment},
) where {T <: PSY.ThermalGen}
    status_init(psi_container, devices)
    output_init(psi_container, devices)
    return
end

function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{D},
) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchFormulation}
    output_init(psi_container, devices)
    return
end
########################### Ramp/Rate of Change Constraints ################################
"""
This function gets the data for the generators for ramping constraints of thermal generators
"""
function _get_data_for_rocc(
    psi_container::PSIContainer,
    ::Type{T},
) where {T <: PSY.ThermalGen}
    resolution = model_resolution(psi_container)
    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        @warn("Not all formulations support under 1-minute resolutions. Exercise caution.")
        minutes_per_period = Dates.value(Dates.Second(resolution)) / 60
    end

    initial_conditions_power = get_initial_conditions(psi_container, DevicePower, T)
    lenght_devices_power = length(initial_conditions_power)
    data = Vector{DeviceRampConstraintInfo}(undef, lenght_devices_power)
    idx = 0
    for (ix, ic) in enumerate(initial_conditions_power)
        g = ic.device
        name = PSY.get_name(g)
        non_binding_up = false
        non_binding_down = false
        ramp_limits = PSY.get_ramp_limits(g)
        if !isnothing(ramp_limits)
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(psi_container)
    data = _get_data_for_rocc(psi_container, T)
    if !isempty(data)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_mixedinteger_rateofchange!(
            psi_container,
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    time_steps = model_time_steps(psi_container)
    data = _get_data_for_rocc(psi_container, T)
    if !isempty(data)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_linear_rateofchange!(
            psi_container,
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{T, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalMultiStart, S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(psi_container)
    data = _get_data_for_rocc(psi_container, T)

    # TODO: Refactor this to a cleaner format that doesn't require passing the device and rate_data this way
    for r in data
        add_device_services!(r, r.ic_status.device, model)
    end
    if !isempty(data)
        device_multistart_rateofchange!(
            psi_container,
            constaint_data,
            make_constraint_name(RAMP, PSY.ThermalMultiStart),
            make_variable_name(ActivePowerVariable, PSY.ThermalMultiStart),
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

########################### start up trajectory constraints ######################################

@doc raw"""
    turbine_temperature(psi_container::PSIContainer,
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
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* rate_data::Vector{DeviceStartUpConstraintInfo},
* cons_name::Symbol : name of the constraint
* var_stop::Symbol : name of the stop variable
* var_starts::Tuple{Symbol, Symbol} : the names of the different start variables
"""
function turbine_temperature(
    psi_container::PSIContainer,
    startup_data::Vector{DeviceStartUpConstraintInfo},
    cons_name::Symbol,
    var_stop::Symbol,
    var_starts::Tuple{Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    start_vars = [
        get_variable(psi_container, var_starts[1]),
        get_variable(psi_container, var_starts[2]),
    ]
    varstop = get_variable(psi_container, var_stop)

    hot_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "hot")
    warm_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "warm")

    names = [get_component_name(st) for st in startup_data]

    con = [
        add_cons_container!(psi_container, hot_name, names, time_steps; sparse = true),
        add_cons_container!(psi_container, warm_name, names, time_steps; sparse = true),
    ]

    # constraint (15)
    for t in time_steps, st in startup_data
        for ix in 1:(st.startup_types - 1)
            if t >= st.time_limits[ix + 1]
                name = get_component_name(st)
                con[ix][name, t] = JuMP.@constraint(
                    psi_container.JuMPmodel,
                    start_vars[ix][name, t] <= sum(
                        varstop[name, t - i]
                        for i in st.time_limits[ix]:(st.time_limits[ix + 1] - 1)
                    )
                )
            end
        end
    end
    return
end

@doc raw"""
    device_start_type_constraint(psi_container::PSIContainer,
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
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* data::Vector{DeviceStartTypesConstraintInfo},
* cons_name::Symbol : name of the constraint
* var_start::Symbol : name of the startup variable
* var_starts::Tuple{Symbol, Symbol} : the names of the different start variables
"""
function device_start_type_constraint(
    psi_container::PSIContainer,
    data::Vector{DeviceStartTypesConstraintInfo},
    cons_name::Symbol,
    var_start::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    varstart = get_variable(psi_container, var_start)
    start_vars = [
        get_variable(psi_container, var_names[1]),
        get_variable(psi_container, var_names[2]),
        get_variable(psi_container, var_names[3]),
    ]

    set_name = [get_component_name(d) for d in data]
    con = add_cons_container!(psi_container, cons_name, set_name, time_steps)

    for t in time_steps, d in data
        # constraint (16)
        name = get_component_name(d)
        con[name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varstart[name, t] == sum(start_vars[ix][name, t] for ix in 1:(d.startup_types))
        )
    end
    return
end

@doc raw"""
    device_startup_initial_condition(psi_container::PSIContainer,
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
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* data::Vector{DeviceStartTypesConstraintInfo},
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol} : the names of the different start variables
* bin_name::Symbol : name of the status variable
"""
function device_startup_initial_condition(
    psi_container::PSIContainer,
    data::Vector{DeviceStartUpConstraintInfo},
    initial_conditions::Vector{InitialCondition},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
    bin_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    T = length(time_steps)

    set_name = [device_name(ic) for ic in initial_conditions]
    up_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    down_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    varbin = get_variable(psi_container, bin_name)
    varstarts = [
        get_variable(psi_container, var_names[1]),
        get_variable(psi_container, var_names[2]),
    ]

    con_ub = add_cons_container!(
        psi_container,
        up_name,
        set_name,
        time_steps,
        1:(MAX_START_STAGES - 1);
        sparse = true,
    )
    con_lb = add_cons_container!(
        psi_container,
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
                    psi_container.JuMPmodel,
                    (d.time_limits[st + 1] - 1) * var[name, t] +
                    (1 - var[name, t]) * M_VALUE >=
                    sum((1 - varbin[name, i]) for i in 1:t) + ic.value
                )
                con_lb[name, t, st] = JuMP.@constraint(
                    psi_container.JuMPmodel,
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(psi_container)
    constraint_data = Vector{DeviceStartUpConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        starttime = PSY.get_start_time_limits(d)
        name = PSY.get_name(d)
        start_types = PSY.get_start_types(d)
        range_data = DeviceStartUpConstraintInfo(name, starttime, start_types)
        constraint_data[ix] = range_data
    end

    turbine_temperature(
        psi_container,
        constraint_data,
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(psi_container)
    constraint_data = Vector{DeviceStartTypesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        start_types = PSY.get_start_types(d)
        range_data = DeviceStartTypesConstraintInfo(name, start_types)
        constraint_data[ix] = range_data
    end

    device_start_type_constraint(
        psi_container,
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
function _get_data_startup_ic(initial_conditions::Vector{InitialCondition})
    lenght_devices = length(initial_conditions)
    data = Vector{DeviceStartUpConstraintInfo}(undef, lenght_devices)
    idx = 0
    for ic in initial_conditions
        g = ic.device
        if PSY.get_start_types(g) > 1
            idx = +1
            name = PSY.get_name(g)
            data[idx] = DeviceStartUpConstraintInfo(
                name,
                PSY.get_start_time_limits(g),
                PSY.get_start_types(g),
            )
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    key_off = ICKey(TimeDurationOFF, PSY.ThermalMultiStart)
    initial_conditions_offtime = get_initial_conditions(psi_container, key_off)
    constraint_data = _get_data_startup_ic(initial_conditions_offtime)

    device_startup_initial_condition(
        psi_container,
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(psi_container)
    forecast_label = "must_run"
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
    )

    device_timeseries_lb!(psi_container, ts_inputs)
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
        non_binding_up = false
        non_binding_down = false
        time_limits = PSY.get_time_limits(g)
        name = PSY.get_name(g)
        if !isnothing(time_limits)
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerModel}
    parameters = model_has_parameters(psi_container)
    resolution = model_resolution(psi_container)
    initial_conditions_on = get_initial_conditions(psi_container, ICKey(TimeDurationON, T))
    initial_conditions_off =
        get_initial_conditions(psi_container, ICKey(TimeDurationOFF, T))
    ini_conds, time_params =
        _get_data_for_tdc(initial_conditions_on, initial_conditions_off, resolution)
    if !(isempty(ini_conds))
        if parameters
            device_duration_parameters!(
                psi_container,
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
                psi_container,
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, ThermalMultiStartUnitCommitment},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    parameters = model_has_parameters(psi_container)
    resolution = model_resolution(psi_container)
    initial_conditions_on = get_initial_conditions(psi_container, ICKey(TimeDurationON, T))
    initial_conditions_off =
        get_initial_conditions(psi_container, ICKey(TimeDurationOFF, T))
    ini_conds, time_params =
        _get_data_for_tdc(initial_conditions_on, initial_conditions_off, resolution)
    if !(isempty(ini_conds))
        if parameters
            device_duration_parameters!(
                psi_container,
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
                psi_container,
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
    psi_container::PSIContainer,
) where {T <: PSY.ThermalGen, U <: AbstractThermalFormulation}
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(psi_container, T),
        has_status_parameter = has_on_parameter(psi_container, T),
        variable_cost = PSY.get_variable,
        start_up_cost = PSY.get_start_up,
        shut_down_cost = PSY.get_shut_down,
        fixed_cost = PSY.get_fixed,
        sos_status = VARIABLE,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    psi_container::PSIContainer,
) where {T <: PSY.ThermalGen, U <: AbstractThermalDispatchFormulation}
    if has_on_parameter(psi_container, T)
        sos_status = PARAMETER
    else
        sos_status = NO_VARIABLE
    end

    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(psi_container, T),
        has_status_parameter = has_on_parameter(psi_container, T),
        variable_cost = PSY.get_variable,
        fixed_cost = PSY.get_fixed,
        sos_status = sos_status,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{ThermalMultiStartUnitCommitment},
    psi_container::PSIContainer,
) where {T <: PSY.ThermalGen}
    fixed_cost_func = x -> PSY.get_fixed(x) + PSY.get_no_load(x)
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(psi_container, T),
        has_status_parameter = has_on_parameter(psi_container, T),
        # variable_cost = PSY.get_variable, uses SOS by default
        shut_down_cost = PSY.get_shut_down,
        fixed_cost = fixed_cost_func,
        sos_status = VARIABLE,
    )
end

"""
Cost function for generators formulated as No-Min
"""
function cost_function!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen}
    no_min_spec = AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(psi_container, T),
        has_status_parameter = has_on_parameter(psi_container, T),
    )

    for g in devices
        component_name = PSY.get_name(g)
        op_cost = PSY.get_operation_cost(g)
        cost_component = PSY.get_variable(op_cost)
        if isa(cost_component, PSY.VariableCost{Array{Tuple{Float64, Float64}, 1}})
            @debug "PWL cost function detected for device $(component_name) using ThermalDispatchNoMin"
            slopes = PSY.get_slopes(cost_component)
            if any(slopes .< 0) || !pwlparamcheck(cost_component)
                throw(IS.InvalidValue("The PWL cost data provided for generator $(PSY.get_name(g)) is not compatible with a No Min Cost."))
            end
            if slopes[1] != 0.0
                @debug "PWL has no 0.0 intercept for generator $(PSY.get_name(g))"
                # adds a first intercept a x = 0.0 and Y below the intercept of the first tuple to make convex equivalent
                first_pair = PSY.get_cost(cost_component)[1]
                cost_function_data = deepcopy(cost_component.cost)
                intercept_point = (0.0, first_pair[2] - COST_EPSILON)
                cost_function_data = vcat(intercept_point, cost_function_data)
                corrected_slopes = PSY.get_slopes(cost_function_data)
                @assert slope_convexity_check(slopes)
            else
                cost_function_data = cost_component.cost
            end
            time_steps = model_time_steps(psi_container)
            for t in time_steps
                pwl_gencost_linear!(
                    psi_container,
                    no_min_spec,
                    component_name,
                    cost_function_data,
                    t,
                )
            end
        else
            add_to_cost!(psi_container, no_min_spec, op_cost, g)
        end
    end
    return
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
