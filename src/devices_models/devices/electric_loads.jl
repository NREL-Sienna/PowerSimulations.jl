abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end
abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end
struct StaticPowerLoad <: AbstractLoadFormulation end
struct InterruptiblePowerLoad <: AbstractControllablePowerLoadFormulation end
struct DispatchablePowerLoad <: AbstractControllablePowerLoadFormulation end

########################### dispatchable load variables ####################################
function activepower_variables!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{L}) where L<:PSY.ElectricLoad
    add_variable(psi_container,
                 devices,
                 Symbol("P_$(L)"),
                 false,
                 :nodal_balance_active, -1.0;
                 ub_value = x -> PSY.get_maxactivepower(x),
                 lb_value = x -> 0.0)
    return
end


function reactivepower_variables!(psi_container::PSIContainer,
                                  devices::IS.FlattenIteratorWrapper{L}) where L<:PSY.ElectricLoad
    add_variable(psi_container,
                 devices,
                 Symbol("Q_$(L)"),
                 false,
                 :nodal_balance_reactive, -1.0;
                 ub_value = x -> PSY.get_maxreactivepower(x),
                 lb_value = x -> 0.0)
    return
end

function commitment_variables!(psi_container::PSIContainer,
                               devices::IS.FlattenIteratorWrapper{L}) where L<:PSY.ElectricLoad

    add_variable(psi_container,
                 devices,
                 Symbol("ON_$(L)"),
                 true)

    return

end

####################################### Reactive Power Constraints #########################
"""
Reactive Power Constraints on Loads Assume Constant PowerFactor
"""
function reactivepower_constraints!(psi_container::PSIContainer,
                                    devices::IS.FlattenIteratorWrapper{L},
                                    model::DeviceModel{L, <:AbstractControllablePowerLoadFormulation},
                                    ::Type{<:PM.AbstractPowerModel},
                                    feed_forward::Union{Nothing, AbstractAffectFeedForward}) where L<:PSY.ElectricLoad
    time_steps = model_time_steps(psi_container)
    key = Symbol("reactive_$(L)")
    psi_container.constraints[key] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_maxreactivepower(d)/PSY.get_maxactivepower(d))))
        psi_container.constraints[key][PSY.get_name(d), t] = JuMP.@constraint(psi_container.JuMPmodel,
                        psi_container.variables[Symbol("Q_$(L)")][name, t] == psi_container.variables[Symbol("P_$(L)")][name, t]*pf)
    end
    return
end


######################## output constraints without Time Series ############################
function _get_time_series(psi_container::PSIContainer,
                          devices::IS.FlattenIteratorWrapper{<:PSY.ElectricLoad},
                          model::DeviceModel = DeviceModel(PSY.PowerLoad, StaticPowerLoad),
                          get_constraint_values::Function = x -> (min = 0.0, max = 0.0))
    initial_time = model_initial_time(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    time_steps = model_time_steps(psi_container)
    device_total = length(devices)

    constraint_data = Vector{DeviceRange}()
    ts_data_active = Vector{DeviceTimeSeries}()
    ts_data_reactive = Vector{DeviceTimeSeries}()

    for device in devices
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        active_power = use_forecast_data ? PSY.get_maxactivepower(device) : PSY.get_activepower(device)
        reactive_power = use_forecast_data ? PSY.get_maxreactivepower(device) : PSY.get_reactivepower(device)
        if use_forecast_data
            forecast = PSY.get_forecast(PSY.Deterministic,
                                        device,
                                        initial_time,
                                        "get_maxactivepower",
                                        length(time_steps))
            ts_vector = TS.values(PSY.get_data(forecast))
        else
            ts_vector = ones(time_steps[end])
        end
        range_data = DeviceRange(name, get_constraint_values(device))
        _device_services!(range_data, device, model)
        push!(constraint_data, range_data)
        push!(ts_data_active, DeviceTimeSeries(name, bus_number, active_power, ts_vector,
                                               range_data))
        push!(ts_data_reactive, DeviceTimeSeries(name, bus_number, reactive_power,
                                                 ts_vector, range_data))

    end

    return ts_data_active, ts_data_reactive, constraint_data

end

function activepower_constraints!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{L},
                                 model::DeviceModel{L, DispatchablePowerLoad},
                                 ::Type{<:PM.AbstractPowerModel},
                                 feed_forward::Union{Nothing, AbstractAffectFeedForward}) where L<:PSY.ElectricLoad
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_active, _, constraint_data = _get_time_series(psi_container, devices, model,
                                                          x -> (min=0.0, max=PSY.get_activepower(x)))

    if !parameters && !use_forecast_data
        device_range(psi_container,
                     constraint_data,
                     Symbol("activerange_$(L)"),
                     Symbol("P_$(L)"))
        return
    end

    if parameters
        device_timeseries_param_ub(psi_container,
                                   ts_data_active,
                                   Symbol("active_$(L)"),
                                   UpdateRef{L}("get_maxactivepower"),
                                   Symbol("P_$(L)"))
    else
        device_timeseries_ub(psi_container,
                            ts_data_active,
                            Symbol("active_$(L)"),
                            Symbol("P_$(L)"))
    end
    return
end

function activepower_constraints!(psi_container::PSIContainer,
                                  devices::IS.FlattenIteratorWrapper{L},
                                  model::DeviceModel{L, InterruptiblePowerLoad},
                                  ::Type{<:PM.AbstractPowerModel},
                                  feed_forward::Union{Nothing, AbstractAffectFeedForward}) where L<:PSY.ElectricLoad
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_active, _, constraint_data = _get_time_series(psi_container, devices, model,
                                                          x -> (min=0.0, max=PSY.get_activepower(x)))

    if !parameters && !use_forecast_data
        device_range(psi_container,
                    constraint_data,
                    Symbol("activerange_$(L)"),
                    Symbol("P_$(L)"))
        return
    end

    if parameters
        device_timeseries_ub_bigM(psi_container,
                                 ts_data_active,
                                 Symbol("active_$(L)"),
                                 Symbol("P_$(L)"),
                                 UpdateRef{L}("get_maxactivepower"),
                                 Symbol("ON_$(L)"))
    else
        device_timeseries_ub_bin(psi_container,
                                ts_data_active,
                                Symbol("active_$(L)"),
                                Symbol("P_$(L)"),
                                Symbol("ON_$(L)"))
    end
    return
end


########################## Addition of to the nodal balances ###############################
function nodal_expression!(psi_container::PSIContainer,
                           devices::IS.FlattenIteratorWrapper{L},
                           ::Type{<:PM.AbstractPowerModel}) where L<:PSY.ElectricLoad
    ts_data_active, ts_data_reactive = _get_time_series(psi_container, devices)
    parameters = model_has_parameters(psi_container)

    if parameters
        include_parameters(psi_container,
                        ts_data_active,
                        UpdateRef{L}("get_maxactivepower"),
                        :nodal_balance_active,
                        -1.0)
        include_parameters(psi_container,
                        ts_data_reactive,
                        UpdateRef{L}("get_maxactivepower"),
                        :nodal_balance_reactive,
                        -1.0)
        return
    end

    for t in model_time_steps(psi_container)
        for device in ts_data_active
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                                device.bus_number,
                                t,
                                -device.multiplier * device.timeseries[t])
        end
        for device in ts_data_reactive
            _add_to_expression!(psi_container.expressions[:nodal_balance_reactive],
                                device.bus_number,
                                t,
                                -device.multiplier * device.timeseries[t])
        end
    end

    return


end

function nodal_expression!(psi_container::PSIContainer,
                           devices::IS.FlattenIteratorWrapper{L},
                           ::Type{<:PM.AbstractActivePowerModel}) where L<:PSY.ElectricLoad
    parameters = model_has_parameters(psi_container)
    ts_data_active, _ = _get_time_series(psi_container, devices)

    if parameters
        include_parameters(psi_container,
                        ts_data_active,
                        UpdateRef{L}("get_maxactivepower"),
                        :nodal_balance_active,
                        -1.0)
        return
    end

    for t in model_time_steps(psi_container), device in ts_data_active
        _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                            device.bus_number,
                            t,
                            -device.multiplier * device.timeseries[t])
    end

    return
end

############################## FormulationControllable Load Cost ###########################
function cost_function(psi_container::PSIContainer,
                       devices::IS.FlattenIteratorWrapper{L},
                       ::Type{DispatchablePowerLoad},
                       ::Type{<:PM.AbstractPowerModel}) where L<:PSY.ControllableLoad
    add_to_cost(psi_container,
                devices,
                Symbol("P_$(L)"),
                :variable,
                -1.0)
    return
end

function cost_function(psi_container::PSIContainer,
                       devices::IS.FlattenIteratorWrapper{L},
                       ::Type{InterruptiblePowerLoad},
                       ::Type{<:PM.AbstractPowerModel}) where L<:PSY.ControllableLoad
    add_to_cost(psi_container,
                devices,
                Symbol("ON_$(L)"),
                :fixed,
                -1.0)
    return
end
