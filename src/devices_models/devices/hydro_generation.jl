abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end
abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end
abstract type AbstractHydroUnitCommitment <: AbstractHydroFormulation end
struct HydroFixed <: AbstractHydroFormulation end
struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end
struct HydroDispatchReservoirFlow <: AbstractHydroDispatchFormulation end
struct HydroDispatchReservoirStorage <: AbstractHydroDispatchFormulation end
struct HydroCommitmentRunOfRiver <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirFlow <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirStorage <: AbstractHydroUnitCommitment end

########################### Hydro generation variables #################################
function activepower_variables!(psi_container::PSIContainer,
                               devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(REAL_POWER, H),
                 false,
                 :nodal_balance_active;
                 lb_value = d -> d.tech.activepowerlimits.min,
                 ub_value = d -> d.tech.activepowerlimits.max,
                 init_value = d -> PSY.get_activepower(PSY.get_tech(d)))

    return
end

function reactivepower_variables!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(REACTIVE_POWER, H),
                 false,
                 :nodal_balance_reactive;
                 ub_value = d -> d.tech.reactivepowerlimits.max,
                 lb_value = d -> d.tech.reactivepowerlimits.min,
                 init_value = d -> d.tech.reactivepower)

    return
end

function energy_variables!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(ENERGY, H),
                 false;
                 ub_value = d -> d.storage_capacity,
                 lb_value = d -> 0.0,
                 init_value = d -> d.initial_storage)

    return
end

function inflow_variables!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(INFLOW, H),
                 false;
                 ub_value = d -> d.inflow,
                 lb_value = d -> 0.0)

    return
end

function spillage_variables!(psi_container::PSIContainer,
                                 devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 variable_name(SPILLAGE, H),
                 false;
                 ub_value = d -> d.inflow,
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
                                    model::DeviceModel{H, AbstractHydroDispatchFormulation},
                                    system_formulation::Type{<:PM.AbstractPowerModel},
                                    feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    constraint_data = Vector(DeviceRange)()
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
        # pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(device))))
        active_power = use_forecast_data ? PSY.get_rating(tech) : PSY.get_activepower(device)
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
        push!(reactive_timeseries, DeviceTimeSeries(name, bus_number, active_power,
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
                                                          x -> (min=0.0, max=PSY.get_activepower(x)))

    if !parameters && !use_forecast_data
        device_range(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(REAL_POWER, H),
        )
        return
    end

    if parameters
        device_timeseries_param_ub(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, H),
            UpdateRef{H}("get_rating"),
            variable_name(REAL_POWER, H),
        )
    else
        device_timeseries_ub(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(REAL_POWER, H),
        )
    end

    return
end

function activepower_constraints!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{H},
                                model::DeviceModel{H, <:AbstractHydroDispatchFormulation},
                                system_formulation::Type{<:PM.AbstractPowerModel},
                                feed_forward::IntegralLimitFF) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_active, _, constraint_data = _get_time_series(psi_container, devices, model,
                                                          x -> (min=0.0, max=PSY.get_activepower(x)))

    device_range(
        psi_container,
        constraint_data,
        constraint_name(ACTIVE_RANGE, H),
        variable_name(REAL_POWER, H),
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
            variable_name(REAL_POWER, H),
            variable_name(ON, H),
        )
        return
    end

    if parameters
        device_timeseries_ub_bigM(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(REAL_POWER, H),
            UpdateRef{H}("get_rating"),
            variable_name(ON, H),
        )
    else
        device_timeseries_ub_bin(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(REAL_POWER, H),
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
                            UpdateRef{H}("get_inflow"),
                            variable_name(INFLOW, H))
    else
        device_timeseries_ub(psi_container,
                            ts_data_inflow,
                            constraint_name(INFLOW_RANGE, H),
                            variable_name(INFLOW, H))
    end

    return
end

######################## Energy balance constraints ############################

function make_efficiency_data(devices::IS.FlattenIteratorWrapper{H}) where {H<:PSY.HydroGen}
    names = Vector{String}(undef, length(devices))
    in_out = Vector{InOut}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        in_out[ix] = (in = 1.0, out = 1.0) #PSY.get_efficiency(d)
    end

    return names, in_out
end

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
    if !(key in keys(psi_container.initial_conditions))
        throw(IS.DataFormatError("Initial Conditions for $(PSY.HydroDispatch) Energy Constraints not in the model"))
    end

    efficiency_data = make_efficiency_data(devices)

    energy_balance(psi_container,
                   psi_container.initial_conditions[key],
                   efficiency_data,
                   constraint_name(ENERGY_CAPACITY, H),
                   (variable_name(INFLOW, H), variable_name(REAL_POWER, H), variable_name(ENERGY, H)))
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
        include_parameters(psi_container,
                           ts_data_active,
                           UpdateRef{H}("get_rating"),
                           :nodal_balance_active)
        include_parameters(psi_container,
                           ts_data_reactive,
                           UpdateRef{H}("get_rating"),
                           :nodal_balance_reactive)
        return
    end

    for t in model_time_steps(psi_container)
        for device_value in ts_data_active
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                            device_value[2],
                            t,
                            device_value[3]*device_value[4][t])
        end
        for device_value in ts_data_reactive
            _add_to_expression!(psi_container.expressions[:nodal_balance_reactive],
                            device_value[2],
                            t,
                            device_value[3]*device_value[4][t])
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
        include_parameters(psi_container,
                           ts_data_active,
                           UpdateRef{H}("get_rating"),
                           :nodal_balance_active)
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
                Symbol("P_HydroDispatch"),
                :fixed,
                -1.0)

    return
end

##################################### Water/Energy Budget Constraint ############################
function _get_budget(psi_container::PSIContainer,
                    devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    initial_time = model_initial_time(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    device_total = length(devices)
    budget_data = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, device_total)

    for (ix, device) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        tech = PSY.get_tech(device)
        # This is where you would get the water/energy storage capacity
        # which is then multiplied by the forecast value to get you the energy budget
        if use_forecast_data
            energy_capacity = PSY.get_storage_capacity(device)
        else
            energy_capacity = PSY.get_activepower(device)
        end
        if use_forecast_data
            ts_vector = TS.values(PSY.get_data(PSY.get_forecast(PSY.Deterministic,
                                                                device,
                                                                initial_time,
                                                                "get_storage_capacity")))
        else
            ts_vector = ones(time_steps[end])
        end
        budget_data[ix] = (name, bus_number, energy_capacity, ts_vector)
    end
    return budget_data
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
    parameters = model_has_parameters(psi_container)
    budget_data  = _get_budget(psi_container, devices)
    if parameters
        device_budget_param_ub(
            psi_container,
            budget_data,
            constraint_name(ENERGY_LIMIT, H),
            UpdateRef{H}("get_storage_capacity"),
            variable_name(REAL_POWER, H),
        )
    else
        device_budget_ub(
            psi_container,
            budget_data,
            constraint_name(ENERGY_LIMIT),
            variable_name(REAL_POWER, H),
        )
    end
end

function device_energy_limit_param_ub(psi_container::PSIContainer,
                                    budget_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    set_name = (r[1] for r in budget_data)
    no_of_budgets = length(budget_data[1][4])
    time_lengths = Int(length(time_steps)/no_of_budgets)
    time_chunks = reshape(collect(time_steps), (time_lengths, no_of_budgets))
    constraint = add_cons_container!(psi_container, cons_name, set_name, 1:no_of_budgets)
    param = add_param_container!(psi_container, param_reference, set_name, 1:no_of_budgets)

    for data in budget_data, i in 1:no_of_budgets
        name = data[1]
        forecast = data[4][i]
        multiplier = data[3]
        param[name, i] = PJ.add_parameter(psi_container.JuMPmodel, forecast)
        constraint[name, i] = JuMP.@constraint(psi_container.JuMPmodel,
                    sum([variable[name, t] for t in time_chunks[:, i]]) <= multiplier*param[name,i])
    end

    return
end


function device_energy_limit_ub(psi_container::PSIContainer,
                                budget_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                                cons_name::Symbol,
                                var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    set_name = (r[1] for r in budget_data)
    no_of_budgets = length(budget_data[1][4])
    time_lengths = Int(length(time_steps)/no_of_budgets)
    time_chunks = reshape(collect(time_steps), (time_lengths, no_of_budgets))
    constraint = add_cons_container!(psi_container, cons_name, set_name, 1:no_of_budgets)

    for data in budget_data, i in 1:no_of_budgets
        name = data[1]
        forecast = data[4][i]
        multiplier = data[3]
        constraint[name, i] = JuMP.@constraint(psi_container.JuMPmodel,
                    sum([variable[name, t] for t in time_chunks[:, i]]) <= multiplier*forecast)
    end

    return
end

function _device_spillage!(range_data::DeviceRange, 
                            device::H, 
                            model::DeviceModel{H, <:AbstractHydroFormulation}) where H<:PSY.HydroGen
    return
end

function _device_spillage!(range_data::DeviceRange, 
                            device::H, 
                            model::DeviceModel{H, HydroDispatchReservoirStorage}) where H<:PSY.HydroGen

    push!(range_data.additional_terms_ub, Symbol("Sp_$H"))
    return
end
