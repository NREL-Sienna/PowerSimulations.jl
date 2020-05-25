########################### Thermal Generation Models ######################################
abstract type AbstractThermalFormulation <: AbstractDeviceFormulation end
abstract type AbstractThermalDispatchFormulation <: AbstractThermalFormulation end
abstract type AbstractThermalUnitCommitment <: AbstractThermalFormulation end
struct ThermalBasicUnitCommitment <: AbstractThermalUnitCommitment end
struct ThermalStandardUnitCommitment <: AbstractThermalUnitCommitment end
struct ThermalDispatch <: AbstractThermalDispatchFormulation end
struct ThermalRampLimited <: AbstractThermalDispatchFormulation end
struct ThermalDispatchNoMin <: AbstractThermalDispatchFormulation end
struct ThermalPGLIBUnitCommitment <: AbstractThermalUnitCommitment end

########################### Active Dispatch Variables ######################################
"""
This function add the variables for power generation output to the model
"""
function activepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    if get_warm_start(psi_container.settings)
        initial_value = d -> PSY.get_activepower(d)
    else
        initial_value = nothing
    end
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, T),
        false,
        :nodal_balance_active;
        ub_value = d -> PSY.get_activepowerlimits(d).max,
        lb_value = d -> PSY.get_activepowerlimits(d).min,
        init_value = initial_value,
    )
    return
end

"""
This function add the variables for power generation output to the model
"""
function activepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
)
    if get_warm_start(psi_container.settings)
        initial_value = d -> PSY.get_activepower(d)
    else
        initial_value = nothing
    end
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, PSY.ThermalPGLIB),
        false,
        :nodal_balance_active;
        ub_value = d -> PSY.get_activepowerlimits(d).max,
        lb_value = d -> 0,
        init_value = initial_value,
    )
    return
end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    if get_warm_start(psi_container.settings)
        initial_value = d -> PSY.get_activepower(d)
    else
        initial_value = nothing
    end
    add_variable(
        psi_container,
        devices,
        variable_name(REACTIVE_POWER, T),
        false,
        :nodal_balance_reactive;
        ub_value = d -> PSY.get_reactivepowerlimits(d).max,
        lb_value = d -> PSY.get_reactivepowerlimits(d).min,
        init_value = initial_value,
    )
    return
end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    time_steps = model_time_steps(psi_container)
    if get_warm_start(psi_container.settings)
        initial_value = d -> (PSY.get_activepower(d) > 0 ? 1.0 : 0.0)
    else
        initial_value = nothing
    end

    add_variable(psi_container, devices, variable_name(ON, T), true)
    var_names = (variable_name(START, T), variable_name(STOP, T))
    for v in var_names
        add_variable(psi_container, devices, v, true; init_value = initial_value)
    end

    return
end

function commitment_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
)
    time_steps = model_time_steps(psi_container)
    if get_warm_start(psi_container.settings)
        initial_value = d -> (PSY.get_activepower(d) > 0 ? 1.0 : 0.0)
    else
        initial_value = nothing
    end

    add_variable(psi_container, devices, variable_name(ON, PSY.ThermalPGLIB), true)
    varstatus = get_variable(psi_container, variable_name(ON, PSY.ThermalPGLIB))
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        bus_number = PSY.get_number(PSY.get_bus(d))
        add_to_expression!(
            get_expression(psi_container, :nodal_balance_active),
            bus_number,
            t,
            varstatus[name, t],
            PSY.get_activepowerlimits(d).min,
        )
    end

    var_names =
        (variable_name(START, PSY.ThermalPGLIB), variable_name(STOP, PSY.ThermalPGLIB))
    for v in var_names
        add_variable(psi_container, devices, v, true)
    end

    return
end

function startup_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
)

    time_steps = model_time_steps(psi_container)
    var_names = (
        variable_name(COLD_START, PSY.ThermalPGLIB),
        variable_name(WARM_START, PSY.ThermalPGLIB),
        variable_name(HOT_START, PSY.ThermalPGLIB),
    )
    for v in var_names
        add_variable(psi_container, devices, v, true)
    end

    return
end

activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{<:PSY.ThermalGen},
    model::DeviceModel{<:PSY.ThermalGen, <:AbstractThermalFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::SemiContinuousFF,
) = nothing

activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{<:PSY.ThermalGen},
    model::DeviceModel{<:PSY.ThermalGen, ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::SemiContinuousFF,
) = nothing

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, <:AbstractThermalDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
) where {T <: PSY.ThermalGen}
    constraint_data = Vector{DeviceRange}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_activepowerlimits(d)
        range_data = DeviceRange(name, limits)
        add_device_services!(range_data, d, model)
        constraint_data[ix] = range_data
    end
    device_range(
        psi_container,
        constraint_data,
        constraint_name(ACTIVE_RANGE, T),
        variable_name(ACTIVE_POWER, T),
    )
    return
end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, <:AbstractThermalFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
) where {T <: PSY.ThermalGen}
    constraint_data = Vector{DeviceRange}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = PSY.get_activepowerlimits(d)
        name = PSY.get_name(d)
        range_data = DeviceRange(name, limits)
        add_device_services!(range_data, d, model)
        constraint_data[ix] = range_data
    end
    device_semicontinuousrange(
        psi_container,
        constraint_data,
        constraint_name(ACTIVE_RANGE, T),
        variable_name(ACTIVE_POWER, T),
        variable_name(ON, T),
    )
    return
end

"""
This function adds the active power limits of generators when there are
    no CommitmentVariables
"""
function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
) where {T <: PSY.ThermalGen}
    constraint_data = Vector{DeviceRange}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = (min = 0.0, max = PSY.get_activepowerlimits(d).max)
        name = PSY.get_name(d)
        range_data = DeviceRange(name, limits)
        add_device_services!(range_data, d, model)
        constraint_data[ix] = range_data
    end

    var_key = variable_name(ACTIVE_POWER, T)
    variable = get_variable(psi_container, var_key)
    # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
    for v in variable
        if JuMP.has_lower_bound(v)
            JuMP.set_lower_bound(v, 0.0)
        end
    end

    device_range(
        psi_container,
        constraint_data,
        constraint_name(ACTIVE_RANGE, T),
        variable_name(ACTIVE_POWER, T),
    )
    return
end

"""
This function adds the active power limits of generators. Constraint (17) & (18) from PGLIB
"""
function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
    model::DeviceModel{PSY.ThermalPGLIB, ThermalPGLIBUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
)
    constraint_data = Vector{DeviceRangePGLIB}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limits = PSY.get_activepowerlimits(d)
        name = PSY.get_name(d)
        startramplimits = PSY.get_powertrajectory(d)
        range_data = DeviceRangePGLIB(name, limits, startramplimits)
        add_device_services!(range_data, d, model)
        constraint_data[ix] = range_data
    end

    device_pglibrange(
        psi_container,
        constraint_data,
        constraint_name(ACTIVE_RANGE, PSY.ThermalPGLIB),
        variable_name(ACTIVE_POWER, PSY.ThermalPGLIB),
        (
            variable_name(ON, PSY.ThermalPGLIB),
            variable_name(START, PSY.ThermalPGLIB),
            variable_name(STOP, PSY.ThermalPGLIB),
        ),
    )

    return
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
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
    model::DeviceModel{PSY.ThermalPGLIB, ThermalPGLIBUnitCommitment},
    system_formulation::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}

    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    key_power = ICKey(DevicePower, PSY.ThermalPGLIB)
    key_status = ICKey(DeviceStatus, PSY.ThermalPGLIB)
    initial_conditions_power = get_initial_conditions(psi_container, key_power)
    initial_conditions_status = get_initial_conditions(psi_container, key_status)
    ini_conds = _get_data_for_range_ic(initial_conditions_power, initial_conditions_status)

    constraint_data = Vector{DeviceRangePGLIB}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = PSY.get_activepowerlimits(d)
        name = PSY.get_name(d)
        @assert name == PSY.get_name(ini_conds[ix, 1].device)
        startramplimits = PSY.get_powertrajectory(d)
        range_data = DeviceRangePGLIB(name, limits, startramplimits)
        add_device_services!(range_data, d, model)
        constraint_data[ix] = range_data
    end

    if !isempty(ini_conds)
        # adds constraint (10)
        device_pglib_range_ic(
            psi_container,
            constraint_data,
            ini_conds,
            constraint_name(ACTIVE_RANGE_IC, PSY.ThermalPGLIB),
            (
                variable_name(ACTIVE_POWER, PSY.ThermalPGLIB),
                variable_name(STOP, PSY.ThermalPGLIB),
            ),
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, <:AbstractThermalDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen}
    constraint_data = Vector{DeviceRange}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_reactivepowerlimits(d)
        range_data = DeviceRange(name, limits)
        #add_device_services!(range_data, d, model)
        # Uncomment when we implement reactive power services
        constraint_data[ix] = range_data
    end

    device_range(
        psi_container,
        constraint_data,
        constraint_name(REACTIVE_RANGE, T),
        variable_name(REACTIVE_POWER, T),
    )
    return
end

"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, <:AbstractThermalFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen}
    constraint_data = Vector{DeviceRange}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = PSY.get_reactivepowerlimits(d)
        name = PSY.get_name(d)
        range_data = DeviceRange(name, limits)
        #add_device_services!(range_data, d, model)
        # Uncomment when we implement reactive power services
        constraint_data[ix] = range_data
    end

    device_semicontinuousrange(
        psi_container,
        constraint_data,
        constraint_name(REACTIVE_RANGE, T),
        variable_name(REACTIVE_POWER, T),
        variable_name(ON, T),
    )
    return
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
    device_commitment(
        psi_container,
        get_initial_conditions(psi_container, ICKey(DeviceStatus, T)),
        constraint_name(COMMITMENT, T),
        (variable_name(START, T), variable_name(STOP, T), variable_name(ON, T)),
    )
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    device_formulation::Type{D},
) where {T <: PSY.ThermalGen, D <: AbstractThermalUnitCommitment}
    status_init(psi_container.initial_conditions, devices)
    output_init(psi_container.initial_conditions, devices)
    duration_init(psi_container.initial_conditions, devices)
    return
end

function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    device_formulation::Type{ThermalBasicUnitCommitment},
) where {T <: PSY.ThermalGen}
    status_init(psi_container.initial_conditions, devices)
    output_init(psi_container.initial_conditions, devices)
    return
end

function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    device_formulation::Type{D},
) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchFormulation}
    output_init(psi_container.initial_conditions, devices)
    return
end

########################### Ramp/Rate of Change constraints ################################
"""
This function gets the data for the generators
"""
function _get_data_for_rocc(
    initial_conditions::Vector{InitialCondition},
    resolution::Dates.TimePeriod,
)
    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        minutes_per_period = Dates.value(Dates.Second(resolution)) / 60
    end
    lenght_devices = length(initial_conditions)
    ini_conds = Vector{InitialCondition}(undef, lenght_devices)
    ramp_params = Vector{UpDown}(undef, lenght_devices)
    minmax_params = Vector{MinMax}(undef, lenght_devices)
    idx = 0
    for ic in initial_conditions
        g = ic.device
        name = PSY.get_name(g)
        non_binding_up = false
        non_binding_down = false
        ramplimits = PSY.get_ramplimits(g)
        rating = PSY.get_rating(g)
        if !isnothing(ramplimits)
            p_lims = PSY.get_activepowerlimits(g)
            max_rate = abs(p_lims.min - p_lims.max) / minutes_per_period
            if (ramplimits.up * rating >= max_rate) & (ramplimits.down * rating >= max_rate)
                @debug "Generator $(name) has a nonbinding ramp limits. Constraints Skipped"
                continue
            else
                idx += 1
            end
            ini_conds[idx] = ic
            ramp_params[idx] = (
                up = ramplimits.up * rating * minutes_per_period,
                down = ramplimits.down * rating * minutes_per_period,
            )
            minmax_params[idx] = p_lims
        end
    end
    if idx < lenght_devices
        deleteat!(ini_conds, (idx + 1):lenght_devices)
        deleteat!(ramp_params, (idx + 1):lenght_devices)
        deleteat!(minmax_params, (idx + 1):lenght_devices)
    end
    return ini_conds, ramp_params, minmax_params
end

"""
This function gets the data for the generators for PGLIB formulation
"""
function _get_data_for_rocc_pglib(
    initial_conditions_power::Vector{InitialCondition},
    initial_conditions_status::Vector{InitialCondition},
    resolution::Dates.TimePeriod,
)
    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        minutes_per_period = Dates.value(Dates.Second(resolution)) / 60
    end
    lenght_devices_power = length(initial_conditions_power)
    lenght_devices_status = length(initial_conditions_status)
    @assert lenght_devices_power == lenght_devices_status
    ini_conds = Matrix{InitialCondition}(undef, lenght_devices_power, 2)
    data = Vector{DeviceRampPGLIB}(undef, lenght_devices_power)
    idx = 0
    for (ix, ic) in enumerate(initial_conditions_power)
        g = ic.device
        @assert g == initial_conditions_status[ix].device
        name = PSY.get_name(g)
        non_binding_up = false
        non_binding_down = false
        ramplimits = PSY.get_ramplimits(g)
        rating = PSY.get_rating(g)
        if !isnothing(ramplimits)
            p_lims = PSY.get_activepowerlimits(g)
            max_rate = abs(p_lims.min - p_lims.max) / minutes_per_period
            if (ramplimits.up * rating >= max_rate) & (ramplimits.down * rating >= max_rate)
                @debug "Generator $(name) has a nonbinding ramp limits. Constraints Skipped"
                continue
            else
                idx += 1
            end
            ini_conds[idx, 1] = ic
            ini_conds[idx, 2] = initial_conditions_status[ix]
            ramp = (
                up = ramplimits.up * rating * minutes_per_period,
                down = ramplimits.down * rating * minutes_per_period,
            )
            data[idx] = DeviceRampPGLIB(name, p_lims, ramp)
        end
    end
    if idx < lenght_devices_power
        ini_conds = ini_conds[1:idx, :]
        deleteat!(data, (idx + 1):lenght_devices_power)
    end
    return ini_conds, data
end

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    system_formulation::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    key = ICKey(DevicePower, T)
    initial_conditions = get_initial_conditions(psi_container, key)
    rate_data = _get_data_for_rocc(initial_conditions, resolution)
    ini_conds, ramp_params, minmax_params =
        _get_data_for_rocc(initial_conditions, resolution)
    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_mixedinteger_rateofchange(
            psi_container,
            (ramp_params, minmax_params),
            ini_conds,
            constraint_name(RAMP, T),
            (
                variable_name(ACTIVE_POWER, T),
                variable_name(START, T),
                variable_name(STOP, T),
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
    system_formulation::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    initial_conditions = get_initial_conditions(psi_container, ICKey(DevicePower, T))
    rate_data = _get_data_for_rocc(initial_conditions, resolution)
    ini_conds, ramp_params, minmax_params =
        _get_data_for_rocc(initial_conditions, resolution)
    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_linear_rateofchange(
            psi_container,
            ramp_params,
            ini_conds,
            constraint_name(RAMP, T),
            variable_name(ACTIVE_POWER, T),
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

function ramp_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
    model::DeviceModel{PSY.ThermalPGLIB, ThermalPGLIBUnitCommitment},
    system_formulation::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}

    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    key_power = ICKey(DevicePower, PSY.ThermalPGLIB)
    key_status = ICKey(DevicePower, PSY.ThermalPGLIB)
    initial_conditions = get_initial_conditions(psi_container, key_power)
    ic_power = get_initial_conditions(psi_container, key_power)
    ic_status = get_initial_conditions(psi_container, key_status)
    ini_conds, constaint_data = _get_data_for_rocc_pglib(ic_power, ic_status, resolution)

    for (ix, ic) in enumerate(ini_conds[:, 1])
        add_device_services!(constaint_data[ix], ic.device, model)
    end
    if !isempty(ini_conds)
        # Adds constraints (8-9) & (19-20) 
        device_pglib_rateofchange(
            psi_container,
            constaint_data,
            ini_conds,
            constraint_name(RAMP, PSY.ThermalPGLIB),
            (
                variable_name(ACTIVE_POWER, PSY.ThermalPGLIB),
                variable_name(START, PSY.ThermalPGLIB),
                variable_name(STOP, PSY.ThermalPGLIB),
            ),
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

########################### start up trajectory constraints ######################################
"""
#TODO: Finish the doc string
"""
function turbine_temperature(
    psi_container::PSIContainer,
    starttime_data::Vector{StartTime},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
    temp_symbol::Tuple{Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    varstart = get_variable(psi_container, var_names[2])
    varstop = get_variable(psi_container, var_names[1])

    set_name = (st.name for st in starttime_data)
    con = add_cons_container!(psi_container, cons_name, set_name, time_steps)

    for t in time_steps, st in starttime_data
        if t >= st.starttime_limits[temp_symbol[2]]
            name = st.name
            # constraint (15)
            con[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                varstart[name, t] <= sum(
                    varstop[name, t - i]
                    for
                    i in
                    st.starttime_limits[temp_symbol[1]]:(st.starttime_limits[temp_symbol[2]] - 1)
                )
            )
        end
    end
    return
end

"""
#TODO: Finish the doc string
"""
function device_start_type_constraint(
    psi_container::PSIContainer,
    data::Vector{String},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    varstart = get_variable(psi_container, var_names[1])
    varcold = get_variable(psi_container, var_names[2])
    varwarm = get_variable(psi_container, var_names[3])
    varhot = get_variable(psi_container, var_names[4])

    set_name = (st for st in data)
    con = add_cons_container!(psi_container, cons_name, set_name, time_steps)

    for t in time_steps, name in data
        # constraint (16)
        con[name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            varstart[name, t] <= varcold[name, t] + varwarm[name, t] + varhot[name, t]
        )
    end
    return
end

"""
#TODO: Finish the doc string
"""
function _get_data_ic_startup_pglib(initial_conditions::Vector{InitialCondition})
    lenght_devices = length(initial_conditions)
    ini_conds = Vector{InitialCondition}(undef, lenght_devices)
    starttime_limits = Vector{StartUp}(undef, lenght_devices)
    for (ix, ic) in enumerate(initial_conditions)
        g = ic.device
        name = PSY.get_name(g)
        starttime_limits[ix] = PSY.get_powertrajectory(g)
        ini_conds[ix] = ic
    end
    return ini_conds, starttime_limits
end

"""
#TODO: Finish the doc string
"""
function device_startup_initial_condition(
    psi_container::PSIContainer,
    data::Vector{StartUp},
    initial_conditions::Vector{InitialCondition},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    T = length(time_steps)
    varcold = get_variable(psi_container, var_names[1])
    varwarm = get_variable(psi_container, var_names[2])
    varhot = get_variable(psi_container, var_names[3])

    set_name = (device_name(ic) for ic in initial_conditions)
    con = add_cons_container!(psi_container, cons_name, set_name, 1)

    for (ix, ic) in enumerate(initial_conditions[:, 1])
        name = device_name(ic)
        # adds contraints (7)
        con[name, 1] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum(
                varwarm[name, t]
                for
                t in max(1, data[ix][:cold] - ic.value + 1):min(T, data[ix][:cold] - 1)
            ) + sum(
                varhot[name, t]
                for
                t in max(1, data[ix][:warm] - ic.value + 1):min(T, data[ix][:cold] - 1)
            ) == 0
        )
    end
    return
end

""" #TODO: Finish the doc string
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function startup_time_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
    model::DeviceModel{PSY.ThermalPGLIB, ThermalPGLIBUnitCommitment},
    system_formulation::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}

    time_steps = model_time_steps(psi_container)
    constraint_data = Vector{StartTime}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        starttime = PSY.get_powertrajectory(d)
        name = PSY.get_name(d)
        range_data = StartTime(name, starttime)
        constraint_data[ix] = range_data
    end
    # adds constraint(15)
    turbine_temperature(
        psi_container,
        constraint_data,
        constraint_name(WARM_START_TIME, PSY.ThermalPGLIB),
        (
            variable_name(WARM_START, PSY.ThermalPGLIB),
            variable_name(STOP, PSY.ThermalPGLIB),
        ),
        (:warm, :cold),
    )

    turbine_temperature(
        psi_container,
        constraint_data,
        constraint_name(HOT_START_TIME, PSY.ThermalPGLIB),
        (variable_name(HOT_START, PSY.ThermalPGLIB), variable_name(STOP, PSY.ThermalPGLIB)),
        (:hot, :warm),
    )
    return
end

"""
#TODO: Finish the doc string
"""
function startup_type_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
    model::DeviceModel{PSY.ThermalPGLIB, ThermalPGLIBUnitCommitment},
    system_formulation::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(psi_container)
    constraint_data = PSY.get_name.(devices)
    # adds constraint (16)
    device_start_type_constraint(
        psi_container,
        constraint_data,
        constraint_name(START_TIME, PSY.ThermalPGLIB),
        (
            variable_name(START, PSY.ThermalPGLIB),
            variable_name(COLD_START, PSY.ThermalPGLIB),
            variable_name(WARM_START, PSY.ThermalPGLIB),
            variable_name(HOT_START, PSY.ThermalPGLIB),
        ),
    )
    return
end

function startup_initial_condition_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
    model::DeviceModel{PSY.ThermalPGLIB, ThermalPGLIBUnitCommitment},
    system_formulation::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {S <: PM.AbstractPowerModel}

    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    key_off = ICKey(TimeDurationOFF, PSY.ThermalPGLIB)
    initial_conditions_offtime = get_initial_conditions(psi_container, key_off)
    ini_conds, starttime_limits = _get_data_ic_startup_pglib(initial_conditions_offtime)
    # adds constraint (7)
    device_startup_initial_condition(
        psi_container,
        starttime_limits,
        ini_conds,
        constraint_name(INITIAL_START_TIME, PSY.ThermalPGLIB),
        (
            variable_name(COLD_START, PSY.ThermalPGLIB),
            variable_name(WARM_START, PSY.ThermalPGLIB),
            variable_name(HOT_START, PSY.ThermalPGLIB),
        ),
    )
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
        timelimits = PSY.get_timelimits(g)
        name = PSY.get_name(g)
        if !isnothing(timelimits)
            if (timelimits.up <= fraction_of_hour) & (timelimits.down <= fraction_of_hour)
                @debug "Generator $(name) has a nonbinding time limits. Constraints Skipped"
            else
                idx += 1
            end
            ini_conds[idx, 1] = ic
            ini_conds[idx, 2] = initial_conditions_off[ix]
            up_val = round(timelimits.up * steps_per_hour, RoundUp)
            down_val = round(timelimits.down * steps_per_hour, RoundUp)
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
    system_formulation::Type{S},
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
            device_duration_parameters(
                psi_container,
                time_params,
                ini_conds,
                constraint_name(DURATION, T),
                (variable_name(ON, T), variable_name(START, T), variable_name(STOP, T)),
            )
        else
            device_duration_retrospective(
                psi_container,
                time_params,
                ini_conds,
                constraint_name(DURATION, T),
                (variable_name(ON, T), variable_name(START, T), variable_name(STOP, T)),
            )
        end
    else
        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"
    end
    return
end

########################### Cost Function Calls#############################################
function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{<:AbstractThermalDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen}
    add_to_cost(psi_container, devices, variable_name(ACTIVE_POWER, T), :variable)
    return
end

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen}
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Minute(resolution)) / 60
    variable = get_variable(psi_container, variable_name(ACTIVE_POWER, T))

    # uses the same cost function whenever there is NO PWL
    function _ps_cost(d::PSY.ThermalGen, cost_component::PSY.VariableCost)
        return ps_cost(
            psi_container,
            variable_name(ACTIVE_POWER, T),
            PSY.get_name(d),
            cost_component,
            dt,
            1.0,
        )
    end

    # This function modified the PWL cost data when present
    function _ps_cost(
        d::PSY.ThermalGen,
        cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
    )
        gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
        if !haskey(psi_container.variables, :PWL_cost_vars)
            time_steps = model_time_steps(psi_container)
            container = add_var_container!(
                psi_container,
                :PWL_cost_vars,
                PSY.get_name(d),
                time_steps,
                1:length(cost_component);
                sparse = true,
            )
        else
            container = get_variable(psi_container, :PWL_cost_vars)
        end
        for (t, var) in enumerate(variable[PSY.get_name(d), :])
            pwlvars = JuMP.@variable(
                psi_container.JuMPmodel,
                [i = 1:length(cost_component)],
                base_name = "{$(variable)}_{pwl}",
                start = 0.0,
                lower_bound = 0.0,
                upper_bound = PSY.get_breakpoint_upperbounds(cost_component)[i]
            )
            slopes = PSY.get_slopes(cost_component)
            first_pair = cost_component.cost[1]
            if slopes[1] != 0.0
                slopes[1] =
                    (
                        first_pair[1]^2 - slopes[1] * first_pair[2] +
                        COST_EPSILON * first_pair[2]
                    ) / (first_pair[1] * first_pair[2])
            end
            if slopes[1] < 0 || slopes[1] <= slopes[2]
                throw(IS.ConflictingInputsError("The PWL cost data provided for generator $(PSY.get_name(d)) is not compatible with a No Min Cost."))
            end
            for (ix, pwlvar) in enumerate(pwlvars)
                JuMP.add_to_expression!(gen_cost, slopes[ix] * pwlvar)
                container[(PSY.get_name(d), t, ix)] = pwlvar
            end

            c = JuMP.@constraint(
                psi_container.JuMPmodel,
                variable == sum([pwlvar for (ix, pwlvar) in enumerate(pwlvars)])
            )
            JuMP.add_to_expression!(gen_cost, c)
        end
        return sign * gen_cost * d
    end

    for d in devices
        cost_component = PSY.get_variable(PSY.get_op_cost(d))
        cost_expression = _ps_cost(d, cost_component)
        T_ce = typeof(cost_expression)
        T_cf = typeof(psi_container.cost_function)
        if T_cf <: JuMP.GenericAffExpr && T_ce <: JuMP.GenericQuadExpr
            psi_container.cost_function += cost_expression
        else
            JuMP.add_to_expression!(psi_container.cost_function, cost_expression)
        end
    end

    return
end

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{<:AbstractThermalFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.ThermalGen}
    #Variable Cost component
    add_to_cost(psi_container, devices, variable_name(ACTIVE_POWER, T), :variable)
    #Commitment Cost Components
    add_to_cost(psi_container, devices, variable_name(START, T), :startup)
    add_to_cost(psi_container, devices, variable_name(STOP, T), :shutdn)
    add_to_cost(psi_container, devices, variable_name(ON, T), :fixed)
    return
end

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalPGLIB},
    ::Type{ThermalPGLIBUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
)
    #Variable Cost component
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Minute(resolution)) / 60
    varp = get_variable(psi_container, variable_name(ACTIVE_POWER, PSY.ThermalPGLIB))
    varon = get_variable(psi_container, variable_name(ON, PSY.ThermalPGLIB))

    # uses the same cost function whenever there is NO PWL
    function _ps_cost(d::PSY.ThermalGen, cost_component::PSY.VariableCost)
        return ps_cost(psi_container, varp[PSY.get_name(d), :], cost_component, dt, 1.0)
    end

    function _ps_cost(
        d::PSY.ThermalGen,
        cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
    )
        gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
        for (ix, variable) in enumerate(varp[PSY.get_name(d), :])
            pwlvars = JuMP.@variable(
                psi_container.JuMPmodel,
                [i = 1:length(cost_component)],
                base_name = "{$(variable)}_{sos}",
                start = 0.0,
                lower_bound = 0.0,
                upper_bound = 1.0
            )

            # Constraint(23)
            JuMP.@constraint(
                psi_container.JuMPmodel,
                sum(pwlvars) <= varon[PSY.get_name(d), ix]
            )
            JuMP.@constraint(
                psi_container.JuMPmodel,
                pwlvars in MOI.SOS2(collect(1:length(pwlvars)))
            )
            # Constraint(22)
            for (ix, var) in enumerate(pwlvars)
                JuMP.add_to_expression!(
                    gen_cost,
                    (cost_component[ix][1] - cost_component[1][1]) * var,
                )
            end

            # Constraint(21)
            JuMP.@constraint(
                psi_container.JuMPmodel,
                variable == sum([
                    var * (cost_component[ix][2] - cost_component[1][2])
                    for (ix, var) in enumerate(pwlvars)
                ])
            )
        end

        return gen_cost
    end

    for d in devices
        cost_component = PSY.get_variable(PSY.get_op_cost(d))
        cost_expression = _ps_cost(d, cost_component)
        T_ce = typeof(cost_expression)
        T_cf = typeof(psi_container.cost_function)
        if T_cf <: JuMP.GenericAffExpr && T_ce <: JuMP.GenericQuadExpr
            psi_container.cost_function += cost_expression
        else
            JuMP.add_to_expression!(psi_container.cost_function, cost_expression)
        end
    end
    ## Start up cost 

    function _ps_cost(d::PSY.ThermalGen, cost_component::StartUp)
        gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
        JuMP.add_to_expression!(
            gen_cost,
            ps_cost(
                psi_container,
                variable_name(COLD_START, PSY.ThermalPGLIB),
                PSY.get_name(d),
                cost_component[:hot],
                dt,
                1.0,
            ),
        )
        JuMP.add_to_expression!(
            gen_cost,
            ps_cost(
                psi_container,
                variable_name(WARM_START, PSY.ThermalPGLIB),
                PSY.get_name(d),
                cost_component[:warm],
                dt,
                1.0,
            ),
        )
        JuMP.add_to_expression!(
            gen_cost,
            ps_cost(
                psi_container,
                variable_name(HOT_START, PSY.ThermalPGLIB),
                PSY.get_name(d),
                cost_component[:cold],
                dt,
                1.0,
            ),
        )
        return gen_cost

    end

    for d in devices
        cost_component = PSY.get_startup(PSY.get_op_cost(d))
        cost_expression = _ps_cost(d, cost_component)
        T_ce = typeof(cost_expression)
        T_cf = typeof(psi_container.cost_function)
        if T_cf <: JuMP.GenericAffExpr && T_ce <: JuMP.GenericQuadExpr
            psi_container.cost_function += cost_expression
        else
            JuMP.add_to_expression!(psi_container.cost_function, cost_expression)
        end
    end
    return
end
