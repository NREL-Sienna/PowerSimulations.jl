abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end
abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end
abstract type AbstractHydroUnitCommitment <: AbstractHydroFormulation end
abstract type AbstractHydroReservoirFormulation <: AbstractHydroDispatchFormulation end
struct HydroFixed <: AbstractHydroFormulation end
struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end
struct HydroDispatchReservoirFlow <: AbstractHydroReservoirFormulation end
struct HydroDispatchReservoirStorage <: AbstractHydroReservoirFormulation end
struct HydroCommitmentRunOfRiver <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirFlow <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirStorage <: AbstractHydroUnitCommitment end

########################### Hydro generation variables #################################
function activepower_variables!(psi_container::PSIContainer,
                               devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(ACTIVE_POWER, H),
                 false,
                 :nodal_balance_active;
                 lb_value = d -> PSY.get_activepowerlimits(PSY.get_tech(d)).min,
                 ub_value = d -> PSY.get_activepowerlimits(PSY.get_tech(d)).max,
                 init_value = d -> PSY.get_activepower(d))

    return
end

function reactivepower_variables!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(REACTIVE_POWER, H),
                 false,
                 :nodal_balance_reactive;
                 ub_value = d -> PSY.get_reactivepowerlimits(PSY.get_tech(d)).max,
                 lb_value = d -> PSY.get_reactivepowerlimits(PSY.get_tech(d)).min,
                 init_value = d -> PSY.get_reactivepower(d))

    return
end

function energy_variables!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(ENERGY, H),
                 false;
                 ub_value = d -> PSY.get_storage_capacity(d),
                 lb_value = d -> 0.0,
                 init_value = d -> PSY.get_initial_storage(d))

    return
end

function inflow_variables!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(INFLOW, H),
                 false;
                 ub_value = d -> PSY.get_inflow(d),
                 lb_value = d -> 0.0)

    return
end

function spillage_variables!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(SPILLAGE, H),
                 false;
                 lb_value = d -> 0.0)

    return
end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables!(psi_container::PSIContainer,
                           devices::IS.FlattenIteratorWrapper{H}) where {H<:PSY.HydroGen}
    time_steps = model_time_steps(psi_container)
    var_names = [variable_name(ON, H), variable_name(START, H), variable_name(STOP, H)]

    for v in var_names
        add_variable(psi_container, devices, v, true)
    end

    return
end

### Constraints for Thermal Generation without commitment variables ####
"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{H},
                                 model::DeviceModel{H, D},
                                 system_formulation::Type{S},
                                 feed_forward::Union{Nothing, AbstractAffectFeedForward}) where {H<:PSY.HydroGen,
                                                                     D<:AbstractHydroUnitCommitment,
                                                                     S<:PM.AbstractPowerModel}
    device_commitment(
        psi_container,
        get_initial_conditions(psi_container, ICKey(DeviceStatus, H)),
        constraint_name(COMMITMENT, H),
        (variable_name(START, H), variable_name(STOP, H), variable_name(ON, H)),
    )

    return
end

####################################### Reactive Power Constraints #########################
function reactivepower_constraints!(psi_container::PSIContainer,
                                    devices::IS.FlattenIteratorWrapper{H},
                                    model::DeviceModel{H, D},
                                    system_formulation::Type{<:PM.AbstractPowerModel},
                                    feed_forward::Union{Nothing, AbstractAffectFeedForward}) where {H<:PSY.HydroGen,
                                                                                                D<:AbstractHydroDispatchFormulation}
    constraint_data = Vector{DeviceRange}()
    for d in devices
        limits =  PSY.get_reactivepowerlimits(PSY.get_tech(d))
        name =  PSY.get_name(d)
        range_data = DeviceRange(name, limits)
        #_device_services!(range_data, d, model)
        # Uncomment when we implement reactive power services
        push!(constraint_data, range_data)
    end

    device_range(
        psi_container,
        constraint_data,
        constraint_name(REACTIVE_RANGE, H),
        variable_name(REACTIVE_POWER, H)
    )
    return
end


######################## output constraints without Time Series ############################
function _get_time_series(psi_container::PSIContainer,
                          devices::IS.FlattenIteratorWrapper{<:PSY.HydroGen},
                          model::DeviceModel,
                          get_constraint_values::Function)
    initial_time = model_initial_time(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)

    constraint_data = Vector{DeviceRange}()
    active_timeseries = Vector{DeviceTimeSeries}()
    reactive_timeseries = Vector{DeviceTimeSeries}()

    for device in devices
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        tech = PSY.get_tech(device)
        # Hydro gens dont't have a power factor field, so the pf calc is commented
        # pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(device))))
        active_power = use_forecast_data ? PSY.get_rating(tech) : PSY.get_activepower(device)
        reactive_power = use_forecast_data ? PSY.get_rating(tech) : PSY.get_reactivepower(device)
        if use_forecast_data
            ts_vector = TS.values(PSY.get_data(PSY.get_forecast(PSY.Deterministic,
                                                                device,
                                                                initial_time,
                                                                "get_rating")))
        else
            ts_vector = ones(time_steps[end])
        end
        range_data = DeviceRange(name, get_constraint_values(device))
        _device_services!(range_data, device, model)
        push!(constraint_data, range_data)
        push!(active_timeseries, DeviceTimeSeries(name, bus_number, active_power, ts_vector,
                                                 range_data))
        # not scaling active power by pf since pf isn't avaialable for hydro gens
        push!(reactive_timeseries, DeviceTimeSeries(name, bus_number, reactive_power,
                                                    ts_vector, range_data))
    end
    return active_timeseries, reactive_timeseries, constraint_data
end


function activepower_constraints!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{H},
                                model::DeviceModel{H, <:AbstractHydroDispatchFormulation},
                                system_formulation::Type{<:PM.AbstractPowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_active, _, constraint_data = _get_time_series(psi_container, devices, model,
                                                          x -> PSY.get_activepowerlimits(PSY.get_tech(x)))

    if !parameters && !use_forecast_data
        device_range(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(ACTIVE_POWER, H),
        )
        return
    end

    if parameters
        device_timeseries_param_ub(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, H),
            UpdateRef{H}(ACTIVE_POWER, "get_rating"),
            variable_name(ACTIVE_POWER, H),
        )
    else
        device_timeseries_ub(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(ACTIVE_POWER, H),
        )
    end

    return
end

function activepower_constraints!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{H},
                                model::DeviceModel{H, <:AbstractHydroReservoirFormulation},
                                system_formulation::Type{<:PM.AbstractPowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_active, _, constraint_data = _get_time_series(psi_container, devices, model,
                                                          x -> PSY.get_activepowerlimits(PSY.get_tech(x)))

    device_range(
        psi_container,
        constraint_data,
        constraint_name(ACTIVE_RANGE, H),
        variable_name(ACTIVE_POWER, H),
    )

    return
end

function activepower_constraints!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{H},
                                model::DeviceModel{H, <:AbstractHydroUnitCommitment},
                                system_formulation::Type{<:PM.AbstractPowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_active, _, constraint_data = _get_time_series(psi_container, devices, model,
                                                          x -> PSY.get_activepowerlimits(PSY.get_tech(x)))

    if !parameters && !use_forecast_data
        device_semicontinuousrange(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(ACTIVE_POWER, H),
            variable_name(ON, H),
        )
        return
    end

    if parameters
        device_timeseries_ub_bigM(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(ACTIVE_POWER, H),
            UpdateRef{H}(ON, "get_rating"),
            variable_name(ON, H),
        )
    else
        device_timeseries_ub_bin(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(ACTIVE_POWER, H),
            variable_name(ON, H),
        )
    end

    return
end

######################## Inflow constraints ############################
function _get_inflow_time_series(psi_container::PSIContainer,
                            devices::IS.FlattenIteratorWrapper{PSY.HydroDispatch},
                            model::DeviceModel{PSY.HydroDispatch, <:AbstractHydroFormulation},
                            get_constraint_values::Function = x -> (min = 0.0, max = 0.0))
    initial_time = model_initial_time(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)

    constraint_data = Vector{DeviceRange}()
    inflow_timeseries = Vector{DeviceTimeSeries}()

    for device in devices
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        inflow_energy = PSY.get_inflow(device)
        if use_forecast_data
            ts_vector = TS.values(PSY.get_data(PSY.get_forecast(PSY.Deterministic,
                                                                device,
                                                                initial_time,
                                                                "get_inflow")))
        else
            ts_vector = ones(time_steps[end])
        end
        range_data = DeviceRange(name, get_constraint_values(device))
        _device_spillage!(range_data, device, model)
        push!(constraint_data, range_data)
        push!(inflow_timeseries, DeviceTimeSeries(name, bus_number, inflow_energy, ts_vector,
                                                 range_data))
    end
    return inflow_timeseries, constraint_data
end
#=
# TODO: Determine if this is useful for ROR formulation ?
function inflow_constraints!(psi_container::PSIContainer,
                            devices::IS.FlattenIteratorWrapper{H},
                            model::DeviceModel{H, <:AbstractHydroDispatchFormulation},
                            system_formulation::Type{<:PM.AbstractPowerModel},
                            feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen

    return
end

function inflow_constraints!(psi_container::PSIContainer,
                            devices::IS.FlattenIteratorWrapper{H},
                            model::DeviceModel{PSY.HydroDispatch, HydroDispatchReservoirStorage},
                            system_formulation::Type{<:PM.AbstractPowerModel},
                            feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_inflow, constraint_data = _get_inflow_time_series(psi_container, devices, model,
                                            x -> (min=0.0, max=PSY.get_inflow(x)))

    if !parameters && !use_forecast_data
        device_range(psi_container,
                     constraint_data,
                     constraint_name(INFLOW_RANGE, H),
                     variable_name(INFLOW, H))
        return
    end

    if parameters
        device_timeseries_param_ub(psi_container,
                            ts_data_inflow,
                            constraint_name(INFLOW_RANGE, H),
                            UpdateRef{H}(INFLOW_RANGE, "get_inflow"),
                            variable_name(INFLOW, H))
    else
        device_timeseries_ub(psi_container,
                            ts_data_inflow,
                            constraint_name(INFLOW_RANGE, H),
                            variable_name(INFLOW, H))
    end

    return
end
=#
####################### Energy balance constraints ############################

function energy_balance_constraint!(psi_container::PSIContainer,
                                   devices::IS.FlattenIteratorWrapper{H},
                                   model::DeviceModel{H, <:AbstractHydroDispatchFormulation},
                                   system_formulation::Type{<:PM.AbstractPowerModel},
                                   feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen

    return
end

function energy_balance_constraint!(psi_container::PSIContainer,
                                   devices::IS.FlattenIteratorWrapper{H},
                                   model::DeviceModel{PSY.HydroDispatch, HydroDispatchReservoirStorage},
                                   system_formulation::Type{<:PM.AbstractPowerModel},
                                   feed_forward::Union{Nothing, AbstractAffectFeedForward}) where {H<:PSY.HydroDispatch}
    key = ICKey(DeviceEnergy, PSY.HydroDispatch)
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !(key in keys(psi_container.initial_conditions))
        throw(IS.DataFormatError("Initial Conditions for $(PSY.HydroDispatch) Energy Constraints not in the model"))
    end

    ts_data_inflow, constraint_data = _get_inflow_time_series(psi_container, devices, model,
                                            x -> (min=0.0, max=PSY.get_inflow(x)))
    if parameters
        reservoir_energy_balance_param(psi_container,
                                        psi_container.initial_conditions[key],
                                        ts_data_inflow,
                                        constraint_name(ENERGY_CAPACITY, H),
                                        (variable_name(SPILLAGE, H), variable_name(REAL_POWER, H), variable_name(ENERGY, H)),
                                        UpdateRef{H}("get_inflow"))
    else
        reservoir_energy_balance(psi_container,
                                psi_container.initial_conditions[key],
                                ts_data_inflow,
                                constraint_name(ENERGY_CAPACITY, H),
                                (variable_name(SPILLAGE, H), variable_name(REAL_POWER, H), variable_name(ENERGY, H)))
    end
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(psi_container::PSIContainer,
                            devices::IS.FlattenIteratorWrapper{H},
                            device_formulation::Type{<:AbstractHydroUnitCommitment}) where {H<:PSY.HydroGen}
    status_init(psi_container, devices)
    output_init(psi_container, devices)
    duration_init(psi_container, devices)

    return
end


function initial_conditions!(psi_container::PSIContainer,
                            devices::IS.FlattenIteratorWrapper{H},
                            device_formulation::Type{D}) where {H<:PSY.HydroGen,
                                                                D<:AbstractHydroDispatchFormulation}
    output_init(psi_container, devices)

    return
end


########################## Addition of to the nodal balances ###############################
function nodal_expression!(psi_container::PSIContainer,
                           devices::IS.FlattenIteratorWrapper{H},
                           system_formulation::Type{<:PM.AbstractPowerModel}) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    ts_data_active, ts_data_reactive, _ = _get_time_series(psi_container, devices,
                                DeviceModel(H, HydroFixed), x -> (min = 0.0, max = 0.0))


    if parameters
        include_parameters(
            psi_container,
            ts_data_active,
            UpdateRef{H}(ACTIVE_POWER, "get_rating"),  # TODO: fix in PR #316
            :nodal_balance_active,
        )
        include_parameters(
            psi_container,
            ts_data_reactive,
            UpdateRef{H}(REACTIVE_POWER, "get_rating"),  # TODO: fix in PR #316
            :nodal_balance_reactive,
        )
        return
    end

    for t in model_time_steps(psi_container)
        for device in ts_data_active
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                            device.bus_number,
                            t,
                            device.multiplier * device.timeseries[t])
        end
        for device in ts_data_reactive
            _add_to_expression!(psi_container.expressions[:nodal_balance_reactive],
                            device.bus_number,
                            t,
                            device.multiplier * device.timeseries[t])
        end
    end

    return
end

function nodal_expression!(psi_container::PSIContainer,
                           devices::IS.FlattenIteratorWrapper{H},
                           system_formulation::Type{<:PM.AbstractActivePowerModel}) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    ts_data_active, _, _  = _get_time_series(psi_container, devices,
                                    DeviceModel(H, HydroFixed), x -> (min = 0.0, max = 0.0))

    if parameters
        include_parameters(
            psi_container,
            ts_data_active,
            UpdateRef{H}(ACTIVE_POWER, "get_rating"),  # TODO: fix in PR #316
            :nodal_balance_active,
        )
        return
    end

    for t in model_time_steps(psi_container)
        for device in ts_data_active
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                            device.bus_number,
                            t,
                            device.multiplier * device.timeseries[t])
        end
    end

    return
end

##################################### Hydro generation cost ############################
function cost_function(psi_container::PSIContainer,
                       devices::IS.FlattenIteratorWrapper{PSY.HydroDispatch},
                       device_formulation::Type{D},
                       system_formulation::Type{<:PM.AbstractPowerModel}) where D<:AbstractHydroFormulation
    add_to_cost(psi_container,
                devices,
                variable_name(ACTIVE_POWER, PSY.HydroDispatch),
                :fixed,
                -1.0)

    return
end

function cost_function(psi_container::PSIContainer,
                       devices::IS.FlattenIteratorWrapper{H},
                       device_formulation::Type{D},
                       system_formulation::Type{<:PM.AbstractPowerModel}) where {D<:AbstractHydroFormulation,
                                                                                H<:PSY.HydroGen}

    return
end

##################################### Water/Energy Limit Constraint ############################
function _get_energy_limit(psi_container::PSIContainer,
                    devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    initial_time = model_initial_time(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    device_total = length(devices)
    energy_limit_data = Vector{DeviceTimeSeries}()

    for (ix, device) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        tech = PSY.get_tech(device)
        # This is where you would get the water/energy storage capacity
        # which is then multiplied by the forecast value to get you the energy limit
        energy_capacity = use_forecast_data ? PSY.get_storage_capacity(device) : PSY.get_activepower(device)
        if use_forecast_data
            forecast = PSY.get_forecast(PSY.Deterministic,
                                        device,
                                        initial_time,
                                        "get_storage_capacity",
                                        length(time_steps))
            ts_vector = TS.values(PSY.get_data(forecast))
        else
            ts_vector = ones(time_steps[end])
        end
        push!(energy_limit_data, DeviceTimeSeries(name, bus_number, energy_capacity, ts_vector, nothing))
    end
    return energy_limit_data
end

function energy_limit_constraints!(psi_container::PSIContainer,
                                    devices::IS.FlattenIteratorWrapper{H},
                                    model::DeviceModel{H, <:AbstractHydroDispatchFormulation},
                                    system_formulation::Type{<:PM.AbstractPowerModel},
                                    feed_forward::IntegralLimitFF) where H<:PSY.HydroGen
    return
end

function energy_limit_constraints!(psi_container::PSIContainer,
                                    devices::IS.FlattenIteratorWrapper{H},
                                    model::DeviceModel{H, <:AbstractHydroDispatchFormulation},
                                    system_formulation::Type{<:PM.AbstractPowerModel},
                                    feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    energy_limit_data  = _get_energy_limit(psi_container, devices)
    if model_has_parameters(psi_container)
        device_energy_limit_param_ub(
            psi_container,
            energy_limit_data,
            constraint_name(ENERGY_LIMIT, H),
            UpdateRef{H}(ENERGY_BUDGET, "get_storage_capacity"),
            variable_name(ACTIVE_POWER, H),
        )
    else
        device_energy_limit_ub(
            psi_container,
            energy_limit_data,
            constraint_name(ENERGY_LIMIT),
            variable_name(ACTIVE_POWER, H),
        )
    end
end

function device_energy_limit_param_ub(psi_container::PSIContainer,
                                    energy_limit_data::Vector{DeviceTimeSeries},
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    set_name = (r.name for r in energy_limit_data)
    constraint = add_cons_container!(psi_container, cons_name, set_name)
    param = add_param_container!(psi_container, param_reference, set_name)

    for data in energy_limit_data
        name = data.name
        multiplier = data.multiplier
        param[name] = PJ.add_parameter(psi_container.JuMPmodel, sum(data.timeseries))
        constraint[name] = JuMP.@constraint(psi_container.JuMPmodel,
                sum([variable[name, t] for t in time_steps]) <= multiplier * param[name])
    end

    return
end


function device_energy_limit_ub(psi_container::PSIContainer,
                                energy_limit_data::Vector{DeviceTimeSeries},
                                cons_name::Symbol,
                                var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    names = (r.name for r in energy_limit_data)
    constraint = add_cons_container!(psi_container, cons_name, names)

    for data in energy_limit_data
        name = data.name
        forecast = data.timeseries
        multiplier = data.multiplier
        constraint[name] = JuMP.@constraint(psi_container.JuMPmodel,
                sum([variable[name, t] for t in time_steps]) <= multiplier * sum(forecast))
    end

    return
end

function _device_spillage!(range_data::DeviceRange,
                            device::H,
                            model::DeviceModel{H, <:AbstractHydroFormulation}) where H<:PSY.HydroGen
    return
end

#=
function _device_spillage!(range_data::DeviceRange,
                            device::H,
                            model::DeviceModel{H, HydroDispatchReservoirStorage}) where H<:PSY.HydroGen

    push!(range_data.additional_terms_ub, Symbol("Sp_$H"))
    return
end
=#
