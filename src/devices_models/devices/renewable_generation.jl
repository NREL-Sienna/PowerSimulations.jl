abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end
abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end
struct RenewableFixed <: AbstractRenewableFormulation end
struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end
struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

########################### renewable generation variables #################################
function activepower_variables!(psi_container::PSIContainer,
                               devices::IS.FlattenIteratorWrapper{R}) where R<:PSY.RenewableGen
    add_variable(psi_container,
                 devices,
                 Symbol("P_$(R)"),
                 false,
                 :nodal_balance_active;
                 lb_value = x -> 0.0,
                 ub_value = x -> PSY.get_rating(PSY.get_tech(x)))
    return
end

function reactivepower_variables!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{R}) where R<:PSY.RenewableGen
    add_variable(psi_container,
                 devices,
                 Symbol("Q_$(R)"),
                 false,
                 :nodal_balance_reactive)
    return
end

####################################### Reactive Power Constraints #########################
function reactivepower_constraints!(psi_container::PSIContainer,
                                    devices::IS.FlattenIteratorWrapper{R},
                                    model::DeviceModel{R, RenewableFullDispatch},
                                    system_formulation::Type{<:PM.AbstractPowerModel},
                                    feed_forward::Union{Nothing, AbstractAffectFeedForward}) where R<:PSY.RenewableGen
    constraint_data = Dict{String, DeviceRange}()
    for (ix, d) in enumerate(devices)
        tech = PSY.get_tech(d)
        name = PSY.get_name(d)
        if isnothing(PSY.get_reactivepowerlimits(tech))
            lims = (min = 0.0, max = 0.0)
            @warn("Reactive Power Limits of $(lims) are nothing. Q_$(lims) is set to 0.0")
        else
            lims = PSY.get_reactivepowerlimits(tech)
        end
        constraint_data[name] = DeviceRange(lims, Vector{Symbol}(), Vector{Symbol}())
    end
    device_range(psi_container,
                constraint_data,
                Symbol("reactiverange_$(R)"),
                Symbol("Q_$(R)"))
    return
end

function reactivepower_constraints!(psi_container::PSIContainer,
                                    devices::IS.FlattenIteratorWrapper{R},
                                    model::DeviceModel{R, RenewableConstantPowerFactor},
                                    system_formulation::Type{<:PM.AbstractPowerModel},
                                    feed_forward::Union{Nothing, AbstractAffectFeedForward}) where R<:PSY.RenewableGen
    names = (PSY.get_name(d) for d in devices)
    time_steps = model_time_steps(psi_container)
    p_variable_name = Symbol("P_$(R)")
    q_variable_name = Symbol("Q_$(R)")
    constraint_name = Symbol("reactiverange_$(R)")
    psi_container.constraints[constraint_name] = JuMPConstraintArray(undef, names, time_steps)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(d))))
        psi_container.constraints[constraint_name][name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                psi_container.variables[q_variable_name][name, t] ==
                                psi_container.variables[p_variable_name][name, t] * pf)
    end
    return
end

######################## output constraints without Time Series ############################
function _get_time_series(psi_container::PSIContainer,
                          devices::IS.FlattenIteratorWrapper{<:PSY.RenewableGen},
                          model::Union{Nothing,DeviceModel} = DeviceModel(PSY.HydroFix, PSI.HydroFixed),
                          get_constraint_values::Function = x -> (min = 0.0, max = 0.0))
    initial_time = model_initial_time(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)

    constraint_data = Dict{String, DeviceRange}()
    active_timeseries = Dict{String, DeviceTimeSeries}()
    reactive_timeseries = Dict{String, DeviceTimeSeries}()

    for device in devices
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        tech = PSY.get_tech(device)
        pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(device))))
        active_power = use_forecast_data ? PSY.get_rating(tech) : PSY.get_activepower(device)
        if use_forecast_data
            forecast = PSY.get_forecast(PSY.Deterministic,
                                        device,
                                        initial_time,
                                        "get_rating",
                                        length(time_steps))
            ts_vector = TS.values(PSY.get_data(forecast))
        else
            ts_vector = ones(time_steps[end])
        end
        active_timeseries[name] = DeviceTimeSeries(bus_number, active_power, ts_vector)
        reactive_timeseries[name] = DeviceTimeSeries(bus_number, active_power * pf, ts_vector)
        constraint_data[name] = DeviceRange(get_constraint_values(device), 
                                            Vector{Symbol}(), 
                                            Vector{Symbol}())
        _device_services(constraint_data[name], device, model)
    end
    return active_timeseries, reactive_timeseries, constraint_data
end

function activepower_constraints!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{R},
                                model::DeviceModel{R, <:AbstractRenewableDispatchFormulation},
                                system_formulation::Type{<:PM.AbstractPowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where R<:PSY.RenewableGen
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_active, _, constraint_data = _get_time_series(psi_container,
                                            devices,
                                            model,
                                            x -> (min = 0.0, max = PSY.get_activepower(x)))

    if !parameters && !use_forecast_data
        device_range(psi_container,
                    constraint_data,
                    Symbol("activerange_$(R)"),
                    Symbol("P_$(R)"))
        return
    end
    if parameters
        device_timeseries_param_ub(psi_container,
                            ts_data_active,
                            constraint_data,
                            Symbol("activerange_$(R)"),
                            UpdateRef{R}("get_rating"),
                            Symbol("P_$(R)"))
    else
        device_timeseries_ub(psi_container,
                            ts_data_active,
                            constraint_data,
                            Symbol("activerange_$(R)"),
                            Symbol("P_$(R)"))
    end
    return
end

########################## Addition of to the nodal balances ###############################
function nodal_expression!(psi_container::PSIContainer,
                           devices::IS.FlattenIteratorWrapper{R},
                           system_formulation::Type{<:PM.AbstractPowerModel}) where R<:PSY.RenewableGen
    parameters = model_has_parameters(psi_container)
    ts_data_active, ts_data_reactive, _ = _get_time_series(psi_container, devices)
    if parameters
        include_parameters(psi_container,
                           ts_data_active,
                           UpdateRef{R}("get_rating"),
                           :nodal_balance_active)
        include_parameters(psi_container,
                           ts_data_reactive,
                           UpdateRef{R}("get_rating"),
                           :nodal_balance_reactive)
        return
    end
    for t in model_time_steps(psi_container)
        for (name, device_value) in ts_data_active
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                            device_value.bus_number,
                            t,
                            device_value.multiplier * device_value.timeseries[t])
        end
        for (name, device_value) in ts_data_reactive
            _add_to_expression!(psi_container.expressions[:nodal_balance_reactive],
                            device_value.bus_number,
                            t,
                            device_value.multiplier * device_value.timeseries[t])
        end
    end
    return
end

function nodal_expression!(psi_container::PSIContainer,
                           devices::IS.FlattenIteratorWrapper{R},
                           system_formulation::Type{<:PM.AbstractActivePowerModel}) where R<:PSY.RenewableGen
    parameters = model_has_parameters(psi_container)
    ts_data_active, ts_data_reactive, _ = _get_time_series(psi_container, devices)
    if parameters
        include_parameters(psi_container,
                           ts_data_active,
                           UpdateRef{R}("get_rating"),
                           :nodal_balance_active)
        return
    end
    for t in model_time_steps(psi_container)
        for (name, device_value) in ts_data_active
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                            device_value.bus_number,
                            t,
                            device_value.multiplier * device_value.timeseries[t])
        end
    end
    return
end

##################################### renewable generation cost ############################
function cost_function(psi_container::PSIContainer,
                       devices::IS.FlattenIteratorWrapper{PSY.RenewableDispatch},
                       device_formulation::Type{D},
                       system_formulation::Type{<:PM.AbstractPowerModel}) where D<:AbstractRenewableDispatchFormulation
    add_to_cost(psi_container,
                devices,
                Symbol("P_RenewableDispatch"),
                :fixed,
                -1.0)
    return
end
