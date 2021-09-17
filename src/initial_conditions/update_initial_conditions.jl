######################### Initial Condition Updating #########################################
function _set_first_initial_conditions!(
    initial_condition_vector::Vector,
    variable::JuMP.Containers.DenseAxisArray{JuMP.VariableRef},
    elapsed_period::Dates.Period,
)
    error("expected")
    for ic in initial_condition_vector
        name = get_component_name(ic)
        var_value = JuMP.value(variable[name, 1])
        calculate_ic_quantity(initial_condition, var_value, elapsed_period)
    end
    return
end

"""
    Used to set the model's first initial conditions
"""
function set_first_initial_conditions!(
    model::OperationModel,
    key::ICKey{InitialTimeDurationOn, T},
) where {T <: PSY.Component}
    ic_container = odel.internal.ic_model_container
    container = get_optimization_container(model)
    ic_var = get_aux_variable(ic_container, TimeDurationOn, T)
    ini_conditions_vector = get_initial_condition(container, key)
    _set_first_initial_conditions(ini_conditions_vector, ic_var)
    # @debug last_status, var_status, abs(last_status - var_status) _group = LOG_GROUP_INITIAL_CONDITIONS
end

function set_first_initial_conditions!(
    model::OperationModel,
    key::ICKey{InitialTimeDurationOff, T},
) where {T <: PSY.Component}
    ic_container = odel.internal.ic_model_container
    container = get_optimization_container(model)
    ic_var = get_aux_variable(ic_container, TimeDurationOff, T)
    ini_conditions_vector = get_initial_condition(container, key)
    _set_first_initial_conditions(ini_conditions_vector, ic_var, 0.0)
    # @debug last_status, var_status, abs(last_status - var_status) _group = LOG_GROUP_INITIAL_CONDITIONS
    return
end

function set_first_initial_conditions!(
    model::OperationModel,
    key::ICKey{DevicePower, T},
) where {T <: PSY.Component}
    ic_container = odel.internal.ic_model_container
    container = get_optimization_container(model)
    ic_var = get_variable(ic_container, ActivePowerVariable, T)
    ini_conditions_vector = get_initial_condition(container, key)
    _set_first_initial_conditions(ini_conditions_vector, ic_var, 0.0)
    # @debug last_status, var_status, abs(last_status - var_status) _group = LOG_GROUP_INITIAL_CONDITIONS
    return
end

#=
""" Updates the initial conditions of the problem"""
function initial_condition_update!(
    model,
    ini_cond_key::ICKey,
    initial_conditions::Vector{InitialCondition},
    ::IntraProblemChronology,
    sim,
)
    # TODO: Replace this convoluted way to get information with access to data store
    execution_count = get_execution_count(problem)
    execution_count == 0 && return
    simulation_cache = sim.internal.simulation_cache
    for ic in initial_conditions
        name = get_component_name(ic)
        interval_chronology = get_model_interval_chronology(sim.sequence, get_name(model))
        var_value = get_model_variable(
            interval_chronology,
            (problem => problem),
            name,
            ic.update_ref,
        )
        # We pass the simulation cache instead of the whole simulation to avoid definition dependencies.
        # All the inputs to calculate_ic_quantity are defined before the simulation object
        quantity = calculate_ic_quantity(
            ini_cond_key,
            ic,
            var_value,
            simulation_cache,
            get_resolution(model),
        )
        previous_value = get_condition(ic)
        PJ.set_value(ic.value, quantity)
        IS.@record :simulation InitialConditionUpdateEvent(
            get_current_time(sim),
            ini_cond_key,
            ic,
            quantity,
            previous_value,
            get_simulation_number(model),
        )
    end
end
=#
