abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end

abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end

abstract type AbstractHydroUnitCommitment <: AbstractHydroFormulation end

struct HydroFixed <: AbstractHydroFormulation end

struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end

struct HydroDispatchSeasonalFlow <: AbstractHydroDispatchFormulation end

struct HydroCommitmentRunOfRiver <: AbstractHydroUnitCommitment end

struct HydroCommitmentSeasonalFlow <: AbstractHydroUnitCommitment end

########################### Hydro generation variables #################################

function activepower_variables!(canonical::Canonical,
                               devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen

    add_variable(canonical,
                 devices,
                 Symbol("P_$(H)"),
                 false,
                 :nodal_balance_active;
                 lb_value = d -> d.tech.activepowerlimits.min,
                 ub_value = d -> d.tech.activepowerlimits.max,
                 init_value = d -> PSY.get_activepower(PSY.get_tech(d)))

    return

end

function reactivepower_variables!(canonical::Canonical,
                                 devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen

    add_variable(canonical,
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
function commitment_variables!(canonical::Canonical,
                           devices::IS.FlattenIteratorWrapper{H}) where {H<:PSY.HydroGen}

    time_steps = model_time_steps(canonical)
    var_names = [Symbol("ON_$(H)"), Symbol("START_$(H)"), Symbol("STOP_$(H)")]

    for v in var_names
        add_variable(canonical, devices, v, true)
    end

    return

end

### Constraints for Thermal Generation without commitment variables ####
"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints!(canonical::Canonical,
                                 devices::IS.FlattenIteratorWrapper{H},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                                     D<:AbstractHydroUnitCommitment,
                                                                     S<:PM.AbstractPowerModel}

    key = ICKey(DeviceStatus, H)

    if !(key in keys(canonical.initial_conditions))
        error("Initial status conditions not provided. This can lead to unwanted results")
    end

    device_commitment(canonical,
                     canonical.initial_conditions[key],
                     Symbol("commitment_$(H)"),
                     (Symbol("START_$(H)"),
                      Symbol("STOP_$(H)"),
                      Symbol("ON_$(H)"))
                      )

    return

end

####################################### Reactive Power Constraints #########################
function reactivepower_constraints!(canonical::Canonical,
                                    devices::IS.FlattenIteratorWrapper{H},
                                    device_formulation::Type{AbstractHydroDispatchFormulation},
                                    system_formulation::Type{<:PM.AbstractPowerModel}) where H<:PSY.HydroGen

    range_data = Vector{NamedMinMax}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        tech = PSY.get_tech(d)
        name = PSY.get_name(d)
        if isnothing(PSY.get_reactivepowerlimits(tech))
            limits = (min = 0.0, max = 0.0)
            range_data[ix] = (PSY.get_name(d), limits)
            @warn("Reactive Power Limits of $(name) are nothing. Q_$(name) is set to 0.0")
        else
            range_data[ix] = (name, PSY.get_reactivepowerlimits(tech))
        end
    end

    device_range(canonical,
                range_data,
                Symbol("reactiverange_$(H)"),
                Symbol("Q_$(H)"))

    return

end


######################## output constraints without Time Series ############################
function _get_time_series(canonical::Canonical,
                          devices::IS.FlattenIteratorWrapper{<:PSY.HydroGen})

    initial_time = model_initial_time(canonical)
    use_forecast_data = model_uses_forecasts(canonical)
    parameters = model_has_parameters(canonical)
    time_steps = model_time_steps(canonical)
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


function activepower_constraints!(canonical::Canonical,
                                devices::IS.FlattenIteratorWrapper{H},
                                device_formulation::Type{<:AbstractHydroDispatchFormulation},
                                system_formulation::Type{<:PM.AbstractPowerModel}) where H<:PSY.HydroGen

    parameters = model_has_parameters(canonical)
    use_forecast_data = model_uses_forecasts(canonical)

    if !parameters && !use_forecast_data
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_rating(PSY.get_tech(d)))) for d in devices]
        device_range(canonical,
                    range_data,
                    Symbol("activerange_$(H)"),
                    Symbol("P_$(H)"))
        return
    end

    ts_data_active, _ = _get_time_series(canonical, devices)
    if parameters
        device_timeseries_param_ub(canonical,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            UpdateRef{H}(:rating),
                            Symbol("P_$(H)"))
    else
        device_timeseries_ub(canonical,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            Symbol("P_$(H)"))
    end

    return

end

function activepower_constraints!(canonical::Canonical,
                                devices::IS.FlattenIteratorWrapper{H},
                                device_formulation::Type{<:AbstractHydroUnitCommitment},
                                system_formulation::Type{<:PM.AbstractPowerModel}) where H<:PSY.HydroGen

    parameters = model_has_parameters(canonical)
    use_forecast_data = model_uses_forecasts(canonical)

    if !parameters && !use_forecast_data
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_rating(PSY.get_tech(d)))) for d in devices]
        device_semicontinuousrange(canonical,
                                    range_data,
                                    Symbol("activerange_$(H)"),
                                    Symbol("P_$(H)"),
                                    Symbol("ON_$(H)"))
        return
    end

    ts_data_active, _ = _get_time_series(canonical, devices)
    if parameters
        device_timeseries_ub_bigM(canonical,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            Symbol("P_$(H)"),
                            UpdateRef{H}(:rating),
                            Symbol("ON_$(H)"))
    else
        device_timeseries_ub_bin(canonical,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            Symbol("P_$(H)"),
                            Symbol("ON_$(H)"))
    end

    return

end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(canonical::Canonical,
                            devices::IS.FlattenIteratorWrapper{H},
                            device_formulation::Type{<:AbstractHydroUnitCommitment}) where {H<:PSY.HydroGen}

    status_init(canonical, devices)
    output_init(canonical, devices)
    duration_init(canonical, devices)

    return

end


function initial_conditions!(canonical::Canonical,
                            devices::IS.FlattenIteratorWrapper{H},
                            device_formulation::Type{D}) where {H<:PSY.HydroGen,
                                                                D<:AbstractHydroDispatchFormulation}

    output_init(canonical, devices)

    return

end


########################## Addition of to the nodal balances ###############################
function nodal_expression!(canonical::Canonical,
                           devices::IS.FlattenIteratorWrapper{H},
                           system_formulation::Type{<:PM.AbstractPowerModel}) where H<:PSY.HydroGen

    parameters = model_has_parameters(canonical)
    ts_data_active, ts_data_reactive = _get_time_series(canonical, devices)

    if parameters
        include_parameters(canonical,
                           ts_data_active,
                           UpdateRef{H}(:rating),
                           :nodal_balance_active)
        include_parameters(canonical,
                           ts_data_reactive,
                           UpdateRef{H}(:rating),
                           :nodal_balance_reactive)
        return
    end

    for t in model_time_steps(canonical)
        for device_value in ts_data_active
            _add_to_expression!(canonical.expressions[:nodal_balance_active],
                            device_value[2],
                            t,
                            device_value[3]*device_value[4][t])
        end
        for device_value in ts_data_reactive
            _add_to_expression!(canonical.expressions[:nodal_balance_reactive],
                            device_value[2],
                            t,
                            device_value[3]*device_value[4][t])
        end
    end

    return

end

function nodal_expression!(canonical::Canonical,
                           devices::IS.FlattenIteratorWrapper{H},
                           system_formulation::Type{<:PM.AbstractActivePowerModel}) where H<:PSY.HydroGen

    parameters = model_has_parameters(canonical)
    ts_data_active, _  = _get_time_series(canonical, devices)

    if parameters
        include_parameters(canonical,
                           ts_data_active,
                           UpdateRef{H}(:rating),
                           :nodal_balance_active)
        return
    end

    for t in model_time_steps(canonical)
        for device_value in ts_data_active
            _add_to_expression!(canonical.expressions[:nodal_balance_active],
                            device_value[2],
                            t,
                            device_value[3]*device_value[4][t])
        end
    end

    return

end

##################################### Hydro generation cost ############################
function cost_function(canonical::Canonical,
                       devices::IS.FlattenIteratorWrapper{PSY.HydroDispatch},
                       device_formulation::Type{D},
                       system_formulation::Type{<:PM.AbstractPowerModel}) where D<:AbstractHydroFormulation

    add_to_cost(canonical,
                devices,
                Symbol("P_HydroDispatch"),
                :fixed,
                -1.0)

    return

end

##################################### Water/Energy Budget Constraint ############################
function _get_budget(canonical::Canonical,
                    devices::IS.FlattenIteratorWrapper{H}) where H<:PSY.HydroGen
    
    initial_time = model_initial_time(canonical)
    use_forecast_data = model_uses_forecasts(canonical)
    parameters = model_has_parameters(canonical)
    time_steps = model_time_steps(canonical)
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

function budget_constraints!(canonical::Canonical,
                    devices::IS.FlattenIteratorWrapper{H},
                    device_formulation::Type{<:AbstractHydroDispatchFormulation},
                    system_formulation::Type{<:PM.AbstractPowerModel}) where H<:PSY.HydroGen

    parameters = model_has_parameters(canonical)
    budget_data  = _get_budget(canonical, devices)
    if parameters
        device_budget_param_ub(canonical,
                            budget_data,
                            Symbol("budget_$(H)"), # TODO: better name for this constraint
                            UpdateRef{H}(:storagecapacity),
                            Symbol("P_$(H)"))
    else
        device_budget_param_ub(canonical,
                            budget_data,
                            Symbol("budget_$(H)"), # TODO: better name for this constraint
                            Symbol("P_$(H)"))
    end
end

function device_budget_param_ub(canonical::Canonical,
                            budget_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                            cons_name::Symbol,
                            param_reference::UpdateRef,
                            var_name::Symbol)

    time_steps = model_time_steps(canonical)
    variable = get_variable(canonical, var_name)
    set_name = (r[1] for r in budget_data)
    no_of_budgets = length(budget_data[1][4])
    time_lengths = time_steps/length(budget_data[1][4])
    time_chunks = reshape(time_steps, (time_lengths, no_of_budgets))
    constraint = _add_cons_container!(canonical, cons_name, set_name, no_of_budgets) 
    param = _add_param_container!(canonical, param_reference, names, no_of_budgets)

    for data in budget_data, i in 1:no_of_budgets
        name = data[1]
        forecast = data[4][i]
        multiplier = data[3]
        param[name] = PJ.add_parameter(canonical.JuMPmodel, forecast)
        constraint[name] = JuMP.@constraint(canonical.JuMPmodel,
                    sum([variable[name, t] for t in time_chunks[:, i]]) <= multiplier*param[name])
    end

    return

end


function device_budget_ub(canonical::Canonical,
                            budget_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                            cons_name::Symbol,
                            var_name::Symbol)

    time_steps = model_time_steps(canonical)
    variable = get_variable(canonical, var_name)
    set_name = (r[1] for r in budget_data)
    no_of_budgets = length(budget_data[1][4])
    time_lengths = time_steps/length(budget_data[1][4])
    time_chunks = reshape(time_steps, (time_lengths, no_of_budgets))
    constraint = _add_cons_container!(canonical, cons_name, set_name, no_of_budgets) 

    for data in budget_data, i in 1:no_of_budgets
        name = data[1]
        forecast = data[4][i]
        multiplier = data[3]
        constraint[name] = JuMP.@constraint(canonical.JuMPmodel,
                    sum([variable[name, t] for t in time_chunks[:, i]]) <= multiplier*forecast)
    end

    return

end
