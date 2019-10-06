#########################TimeSeries Data Updating###########################################
function parameter_update!(param_reference::UpdateRef{T},
                           param_array::JuMPParamArray,
                           stage_number::Int64,
                           sim::Simulation) where T <: PSY.Component

    forecasts = PSY.get_component_forecasts(T, sim.stages[stage_number].sys,
                                               sim.ref.date_ref[stage_number])
    for forecast in forecasts
        device = PSY.get_forecast_component_name(forecast)
        for (ix, val) in enumerate(param_array[device,:])
            value = PSY.get_forecast_value(forecast, ix)
            JuMP.fix(val, value)
        end
    end

    return

end

# This makes the choice in which variable to get from the results.

function _get_stage_variable(chron::Type{RecedingHorizon},
                           from_stage::_Stage,
                           device_name::String,
                           var_ref::UpdateRef,
                           to_stage_execution_count::Int64)

    variable = get_value(from_stage.canonical, var_ref)
    step = axes(variable)[2][1]
    return JuMP.value(variable[device_name, step])
end

function _get_stage_variable(chron::Type{Sequential},
                             from_stage::_Stage,
                             device_name::String,
                             var_ref::UpdateRef,
                             to_stage_execution_count::Int64)

    variable = get_value(from_stage.canonical, var_ref)
    step = axes(variable)[2][end]
    return JuMP.value(variable[device_name, step])
end

function _get_stage_variable(chron::Type{Synchronize},
                            from_stage::_Stage,
                            device_name::String,
                            var_ref::UpdateRef,
                            to_stage_execution_count::Int64)

    variable = get_value(from_stage.canonical, var_ref)
    step = axes(variable)[2][to_stage_execution_count + 1]
    return JuMP.value(variable[device_name, step])
end

################################Cache Update################################################
function _update_cache!(c::TimeStatusChange, stage::_Stage)
    parameter = get_value(stage.canonical, c.ref)

    for name in parameter.axes[1]
        param_status = PJ.value(parameter[name])
        if c.value[name][:status] == param_status
            c.value[name][:count] += 1.0
        elseif c.value[name][:status] != param_status
            c.value[name][:count] = 1.0
            c.value[name][:status] = param_status
        end
    end

    return
end

#########################FeedForward Variables Updating#####################################

function feedforward_update(::Type{Chron},
                            param_reference::UpdateRef{JuMP.VariableRef},
                            param_array::JuMPParamArray,
                            to_stage::_Stage,
                            from_stage::_Stage) where Chron <: Chronology

    to_stage_execution_count = to_stage.execution_count
    for device_name in axes(param_array)[1]
        var_value = _get_stage_variable(Chron, from_stage, device_name, param_reference, to_stage_execution_count)
        PJ.fix(param_array[device_name], var_value)
    end

    return

end

#########################Initial Condition Updating#########################################

# TODO: Consider when more than one UC model is used for the stages that the counts need
# to be scaled.
function _calculate_ic_quantity(initial_condition_key::ICKey{TimeDurationOFF, PSD},
                                ic::InitialCondition,
                                var_value::Float64,
                                cache::Union{Nothing,AbstractCache}) where PSD <: PSY.Device

    name = device_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = var_value > eps() ? 1.0 : 0.0
    @assert last_status == var_status

    if last_status >= 1.0
        return current_counter
    end

    if last_status < 1.0
        return 0.0
    end
end

function _calculate_ic_quantity(initial_condition_key::ICKey{TimeDurationON, PSD},
                                ic::InitialCondition,
                                var_value::Float64,
                                cache::Union{Nothing,AbstractCache}) where PSD <: PSY.Device

    name = device_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = var_value > eps() ? 1.0 : 0.0
    @assert last_status == var_status

    if last_status >= 1.0
        return 0.0
    end

    if last_status < 1.0
        return current_counter
    end

end

function _calculate_ic_quantity(initial_condition_key::ICKey{DeviceStatus, PSD},
                                ic::InitialCondition,
                                var_value::Float64,
                                cache::Union{Nothing,AbstractCache}) where PSD <: PSY.Device
    return var_value > eps() ? 1.0 : 0.0
end

function _calculate_ic_quantity(initial_condition_key::ICKey{DevicePower, PSD},
                               ic::InitialCondition,
                               var_value::Float64,
                               cache::Union{Nothing,AbstractCache}) where PSD <: PSY.ThermalGen


    if isnothing(cache)
        status_change_to_on = value(ic) <= eps() && var_value >= eps()
        status_change_to_off = value(ic) >= eps() && var_value <= eps()
    else
        name = device_name(ic)
        time_cache = cache_value(cache, name)
        status_change_to_on = time_cache[:status] >= eps() && var_value <= eps()
        status_change_to_off = time_cache[:status] <= eps() && var_value >= eps()
    end


    if status_change_to_on
        return ic.device.tech.activepowerlimits.min
    end

    if status_change_to_off
        return 0.0
    end

    return var_value
end

function _initial_condition_update!(initial_condition_key::ICKey,
                                    ::Type{Chron},
                                    ini_cond_vector::Vector{InitialCondition},
                                    to_stage::_Stage,
                                    from_stage::_Stage) where Chron <: Chronology

    to_stage_execution_count = to_stage.execution_count
    for ic in ini_cond_vector
        name = device_name(ic)
        update_ref = ic.update_ref
        var_value = _get_stage_variable(Chron, from_stage, name, update_ref, to_stage_execution_count)
        cache = get(from_stage.cache, ic.cache, nothing)
        quantity = _calculate_ic_quantity(initial_condition_key, ic, var_value, cache)
        PJ.fix(ic.value, quantity)
    end

    return

end

function _initial_condition_update!(initial_condition_key::ICKey,
                                    ::Nothing,
                                    ini_cond_vector::Vector{InitialCondition},
                                    to_stage::_Stage,
                                    from_stage::_Stage)
        # Meant to do nothing
    return
end

#############################Interfacing Functions##########################################

function cache_update!(stage::_Stage)


    for (k, v) in stage.cache
        _update_cache!(v, stage)
    end

    return

end

"""Updates the forecast parameter value"""
function parameter_update!(param_reference::UpdateRef{JuMP.VariableRef},
                           param_array::JuMPParamArray,
                           stage_number::Int64,
                           sim::Simulation)
    chronology_ref = sim.stages[stage_number].chronology_ref
    current_stage = sim.stages[stage_number]
    for (k, ref) in chronology_ref
        feedforward_update(ref, param_reference, param_array, current_stage, sim.stages[k])
    end

    return

end

function intial_condition_update!(initial_condition_key::ICKey,
                                  ini_cond_vector::Vector{InitialCondition},
                                  stage_number::Int64,
                                  step::Int64,
                                  sim::Simulation)

    chronology_ref = nothing
    current_stage = sim.stages[stage_number]
    #checks if current stage is the first in the step and the execution is the first to
    # look backwards on the previous step
    intra_step_update = (stage_number == 1 && current_stage.execution_count == 0)
    #checks if current execution is the first execution to look into the previuous stage
    intra_stage_update = (stage_number > 1 && current_stage.execution_count == 0)
    #checks that the current run and stage ininital conditions is based on the current results
    inner_stage_update = (stage_number > 1 && current_stage.execution_count > 0)
    # makes the update based on the last stage.
    if intra_step_update
        from_stage = sim.stages[end]
        chronology_ref = sim.stages[stage_number].ini_cond_chron
    # Updates the next stage in the same step
    elseif intra_stage_update
        from_stage = sim.stages[stage_number-1]
        chronology_ref = sim.stages[stage_number].chronology_ref[stage_number-1]
    # Update is done on the current stage
    elseif inner_stage_update
        from_stage = current_stage
        chronology_ref = sim.stages[stage_number].ini_cond_chron
    else
        error("Condition not implemented")
    end
    _initial_condition_update!(initial_condition_key,
                               chronology_ref,
                               ini_cond_vector,
                               current_stage,
                               from_stage)

    return

end

function update_stage!(stage::_Stage{M}, step::Int64, sim::Simulation) where M<:AbstractOperationModel
    # Is first run of first stage? Yes -> do nothing
    (step == 1 && stage.key == 1 && stage.execution_count == 0) && return

    for (k, v) in stage.canonical.parameters
        parameter_update!(k, v, stage.key, sim)
    end

    cache_update!(stage)

    # Set initial conditions of the stage I am about to run.
    for (k, v) in stage.canonical.initial_conditions
        intial_condition_update!(k, v, stage.key, step, sim)
    end

    return

end
