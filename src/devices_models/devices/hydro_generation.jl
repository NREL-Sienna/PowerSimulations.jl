abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end
abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end
abstract type AbstractHydroUnitCommitment <: AbstractHydroFormulation end
struct HydroFixed <: AbstractHydroFormulation end
struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end
struct HydroDispatchSeasonalFlow <: AbstractHydroDispatchFormulation end
struct HydroCommitmentRunOfRiver <: AbstractHydroUnitCommitment end
struct HydroCommitmentSeasonalFlow <: AbstractHydroUnitCommitment end

########################### Hydro generation variables #################################
function activepower_variables!(psi_container::PSIContainer,
                               devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    add_variable(psi_container,
                 devices,
                 Symbol("P_$(H)"),
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
                 Symbol("Q_$(H)"),
                 false,
                 :nodal_balance_reactive,
                 ub_value = d -> d.tech.reactivepowerlimits.max,
                 lb_value = d -> d.tech.reactivepowerlimits.min,
                 init_value = d -> d.tech.reactivepower)

    return
end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables!(psi_container::PSIContainer,
                           devices::IS.FlattenIteratorWrapper{H}) where {H<:PSY.HydroGen}
    time_steps = model_time_steps(psi_container)
    var_names = [Symbol("ON_$(H)"), Symbol("START_$(H)"), Symbol("STOP_$(H)")]

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
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 feed_forward::Union{Nothing, AbstractAffectFeedForward}) where {H<:PSY.HydroGen,
                                                                     D<:AbstractHydroUnitCommitment,
                                                                     S<:PM.AbstractPowerModel}
    key = ICKey(DeviceStatus, H)

    if !(key in keys(psi_container.initial_conditions))
        error("Initial status conditions not provided. This can lead to unwanted results")
    end

    device_commitment(psi_container,
                     psi_container.initial_conditions[key],
                     Symbol("commitment_$(H)"),
                     (Symbol("START_$(H)"),
                      Symbol("STOP_$(H)"),
                      Symbol("ON_$(H)"))
                      )

    return
end

####################################### Reactive Power Constraints #########################
function reactivepower_constraints!(psi_container::PSIContainer,
                                    devices::IS.FlattenIteratorWrapper{H},
                                    device_formulation::Type{AbstractHydroDispatchFormulation},
                                    system_formulation::Type{<:PM.AbstractPowerModel},
                                    feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    names = Vector{String}(undef, length(devices))
    limit_values = Vector{MinMax}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limit_values[ix] = PSY.get_reactivepowerlimits(PSY.get_tech(d))
        names[ix] = PSY.get_name(d)
    end

    device_range(psi_container,
                 DeviceRange(names, limit_values, Vector{Vector{Symbol}}(), Vector{Vector{Symbol}}()),
                 Symbol("reactiverange_$(H)"),
                 Symbol("Q_$(H)"))
    return
end


######################## output constraints without Time Series ############################
function _get_time_series(psi_container::PSIContainer,
                          devices::IS.FlattenIteratorWrapper{<:PSY.HydroGen})
    initial_time = model_initial_time(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    device_total = length(devices)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, device_total)
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, device_total)

    for (ix, device) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        tech = PSY.get_tech(device)
        # pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(device))))
        active_power = use_forecast_data ? PSY.get_rating(tech) : PSY.get_activepower(device)
        if use_forecast_data
            ts_vector = TS.values(PSY.get_data(PSY.get_forecast(PSY.Deterministic,
                                                                device,
                                                                initial_time,
                                                                "rating")))
        else
            ts_vector = ones(time_steps[end])
        end
        ts_data_active[ix] = (name, bus_number, active_power, ts_vector)
        ts_data_reactive[ix] = ts_data_active[ix] # (name, bus_number, active_power * pf, ts_vector)
    end

    return ts_data_active, ts_data_reactive
end


function activepower_constraints!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{H},
                                device_formulation::Type{<:AbstractHydroDispatchFormulation},
                                system_formulation::Type{<:PM.AbstractPowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !parameters && !use_forecast_data
        names = Vector{String}(undef, length(devices))
        limit_values = Vector{MinMax}(undef, length(devices))
        for (ix, d) in enumerate(devices)
            ub_value = PSY.get_activepower(d)
            limit_values[ix] = (min=0.0, max=ub_value)
            names[ix] = PSY.get_name(d)
        end
        device_range(psi_container,
        DeviceRange(names, limit_values, Vector{Vector{Symbol}}(), Vector{Vector{Symbol}}()),
                    Symbol("activerange_$(H)"),
                    Symbol("P_$(H)"))
        return
    end

    ts_data_active, _ = _get_time_series(psi_container, devices)
    if parameters
        device_timeseries_param_ub(psi_container,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            UpdateRef{H}(:rating),
                            Symbol("P_$(H)"))
    else
        device_timeseries_ub(psi_container,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            Symbol("P_$(H)"))
    end

    return
end

function activepower_constraints!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{H},
                                device_formulation::Type{<:AbstractHydroUnitCommitment},
                                system_formulation::Type{<:PM.AbstractPowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !parameters && !use_forecast_data

        names = Vector{String}(undef, length(devices))
        limit_values = Vector{MinMax}(undef, length(devices))
        additional_terms_ub = Vector{Vector{Symbol}}(undef, length(devices))
        additional_terms_lb = Vector{Vector{Symbol}}(undef, length(devices))
        range_data = DeviceRange(names, limit_values, additional_terms_ub, additional_terms_ub)
        for (ix, d) in enumerate(devices)
            limit_values[ix] = PSY.get_activepowerlimits(PSY.get_tech(d))
            names[ix] = PSY.get_name(d)
            services_ub = Vector{Symbol}()
            services_lb = Vector{Symbol}()
            for service in PSY.get_services(d)
                SR = typeof(service)
                push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
            end
            additional_terms_ub[ix] = services_ub
            additional_terms_lb[ix] = services_lb
        end
        device_semicontinuousrange(psi_container,
                                    range_data,
                                    Symbol("activerange_$(H)"),
                                    Symbol("P_$(H)"),
                                    Symbol("ON_$(H)"))
        return
    end

    ts_data_active, _ = _get_time_series(psi_container, devices)
    if parameters
        device_timeseries_ub_bigM(psi_container,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            Symbol("P_$(H)"),
                            UpdateRef{H}(:rating),
                            Symbol("ON_$(H)"))
    else
        device_timeseries_ub_bin(psi_container,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            Symbol("P_$(H)"),
                            Symbol("ON_$(H)"))
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
    ts_data_active, ts_data_reactive = _get_time_series(psi_container, devices)

    if parameters
        include_parameters(psi_container,
                           ts_data_active,
                           UpdateRef{H}(:rating),
                           :nodal_balance_active)
        include_parameters(psi_container,
                           ts_data_reactive,
                           UpdateRef{H}(:rating),
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
    ts_data_active, _  = _get_time_series(psi_container, devices)

    if parameters
        include_parameters(psi_container,
                           ts_data_active,
                           UpdateRef{H}(:rating),
                           :nodal_balance_active)
        return
    end

    for t in model_time_steps(psi_container)
        for device_value in ts_data_active
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                            device_value[2],
                            t,
                            device_value[3]*device_value[4][t])
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
        energy_capacity = use_forecast_data ? PSY.get_storagecapacity(device) : PSY.get_activepower(device)
        if use_forecast_data
            ts_vector = TS.values(PSY.get_data(PSY.get_forecast(PSY.Deterministic,
                                                                device,
                                                                initial_time,
                                                                "storagecapacity")))
        else
            ts_vector = ones(time_steps[end])
        end
        budget_data[ix] = (name, bus_number, energy_capacity, ts_vector)
    end
    return budget_data
end

function budget_constraints!(psi_container::PSIContainer,
                    devices::IS.FlattenIteratorWrapper{H},
                    device_formulation::Type{<:AbstractHydroDispatchFormulation},
                    system_formulation::Type{<:PM.AbstractPowerModel},
                    feed_forward::Union{Nothing, AbstractAffectFeedForward}) where H<:PSY.HydroGen
    parameters = model_has_parameters(psi_container)
    budget_data  = _get_budget(psi_container, devices)
    if parameters
        device_budget_param_ub(psi_container,
                            budget_data,
                            Symbol("budget_$(H)"), # TODO: better name for this constraint
                            UpdateRef{H}(:storagecapacity),
                            Symbol("P_$(H)"))
    else
        device_budget_param_ub(psi_container,
                            budget_data,
                            Symbol("budget_$(H)"), # TODO: better name for this constraint
                            Symbol("P_$(H)"))
    end
end

function device_budget_param_ub(psi_container::PSIContainer,
                            budget_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                            cons_name::Symbol,
                            param_reference::UpdateRef,
                            var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    set_name = (r[1] for r in budget_data)
    no_of_budgets = length(budget_data[1][4])
    time_lengths = time_steps/length(budget_data[1][4])
    time_chunks = reshape(time_steps, (time_lengths, no_of_budgets))
    constraint = _add_cons_container!(psi_container, cons_name, set_name, no_of_budgets)
    param = _add_param_container!(psi_container, param_reference, names, no_of_budgets)

    for data in budget_data, i in 1:no_of_budgets
        name = data[1]
        forecast = data[4][i]
        multiplier = data[3]
        param[name] = PJ.add_parameter(psi_container.JuMPmodel, forecast)
        constraint[name] = JuMP.@constraint(psi_container.JuMPmodel,
                    sum([variable[name, t] for t in time_chunks[:, i]]) <= multiplier*param[name])
    end

    return
end


function device_budget_ub(psi_container::PSIContainer,
                            budget_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                            cons_name::Symbol,
                            var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    set_name = (r[1] for r in budget_data)
    no_of_budgets = length(budget_data[1][4])
    time_lengths = time_steps/length(budget_data[1][4])
    time_chunks = reshape(time_steps, (time_lengths, no_of_budgets))
    constraint = _add_cons_container!(psi_container, cons_name, set_name, no_of_budgets)

    for data in budget_data, i in 1:no_of_budgets
        name = data[1]
        forecast = data[4][i]
        multiplier = data[3]
        constraint[name] = JuMP.@constraint(psi_container.JuMPmodel,
                    sum([variable[name, t] for t in time_chunks[:, i]]) <= multiplier*forecast)
    end

    return
end
