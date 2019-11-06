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
        device_range(canonical,
                    range_data,
                    Symbol("activerange_$(H)"),
                    Symbol("P_$(H)"))
        return
    end

    ts_data_active, _ = _get_time_series(canonical, devices)
    if parameters
        device_timeseries_ub_bigM(canonical,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            UpdateRef{H}(:rating),
                            Symbol("P_$(H)"))
    else
        device_timeseries_ub_bin(canonical,
                            ts_data_active,
                            Symbol("activerange_$(H)"),
                            Symbol("P_$(H)"))
    end

    return

end

function activepower_constraints!(canonical::Canonical,
                                devices::IS.FlattenIteratorWrapper{H},
                                device_formulation::Type{HydroCommitmentSeasonalFlow},
                                system_formulation::Type{<:PM.AbstractPowerModel}) where H<:PSY.HydroGen

    range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_rating(PSY.get_tech(d)))) for d in devices]
    device_semicontinuousrange(canonical,
                                range_data,
                                Symbol("activerange_$(H)"),
                                Symbol("P_$(H)"),
                                Symbol("ON_$(H)"))

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
                                                                D<:AbstractHydroFormulation}

    output_init(canonical, devices)

    return

end


########################### Ramp/Rate of Change constraints ################################
"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints!(canonical::Canonical,
                           devices::IS.FlattenIteratorWrapper{H},
                           device_formulation::Type{<:AbstractHydroUnitCommitment},
                           system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                        S<:PM.AbstractPowerModel}
    key = ICKey(DevicePower, H)

    if !(key in keys(canonical.initial_conditions))
        error("Initial Conditions for $(H) Rate of Change Constraints not in the model")
    end

    time_steps = model_time_steps(canonical)
    resolution = model_resolution(canonical)
    initial_conditions = get_initial_conditions(canonical, key)
    ini_conds, ramp_params, minmax_params = _get_data_for_rocc(initial_conditions, resolution)

    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_mixedinteger_rateofchange(canonical,
                                         (ramp_params, minmax_params),
                                         ini_conds,
                                         Symbol("ramp_$(H)"),
                                        (Symbol("P_$(H)"),
                                         Symbol("START_$(H)"),
                                         Symbol("STOP_$(H)"))
                                        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end

function ramp_constraints!(canonical::Canonical,
                          devices::IS.FlattenIteratorWrapper{H},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                   D<:AbstractHydroFormulation,
                                                   S<:PM.AbstractPowerModel}

    key = ICKey(DevicePower, H)

    if !(key in keys(canonical.initial_conditions))
        error("Initial Conditions for $(H) Rate of Change Constraints not in the model")
    end

    time_steps = model_time_steps(canonical)
    resolution = model_resolution(canonical)
    initial_conditions = get_initial_conditions(canonical, key)
    rate_data = _get_data_for_rocc(initial_conditions, resolution)
    ini_conds, ramp_params, minmax_params = _get_data_for_rocc(initial_conditions, resolution)

    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_linear_rateofchange(canonical,
                                  ramp_params,
                                  ini_conds,
                                   Symbol("ramp_$(H)"),
                                   Symbol("P_$(H)"))
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end

########################### time duration constraints ######################################


function time_constraints!(canonical::Canonical,
                          devices::IS.FlattenIteratorWrapper{H},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                   D<:AbstractHydroUnitCommitment,
                                                   S<:PM.AbstractPowerModel}

    ic_keys = [ICKey(TimeDurationON, H), ICKey(TimeDurationOFF, H)]
    for key in ic_keys
        if !(key in keys(canonical.initial_conditions))
            error("Initial Conditions for $(H) Time Constraint not in the model")
        end
    end

    parameters = model_has_parameters(canonical)
    resolution = model_resolution(canonical)
    initial_conditions_on  = get_initial_conditions(canonical, ic_keys[1])
    initial_conditions_off = get_initial_conditions(canonical, ic_keys[2])
    ini_conds, time_params = _get_data_for_tdc(initial_conditions_on,
                                               initial_conditions_off,
                                               resolution)

    if !(isempty(ini_conds))
       if parameters
            device_duration_parameters(canonical,
                                time_params,
                                ini_conds,
                                Symbol("duration_$(H)"),
                                (Symbol("ON_$(H)"),
                                Symbol("START_$(H)"),
                                Symbol("STOP_$(H)"))
                                      )
        else
            device_duration_retrospective(canonical,
                                        time_params,
                                        ini_conds,
                                        Symbol("duration_$(H)"),
                                        (Symbol("ON_$(H)"),
                                        Symbol("START_$(H)"),
                                        Symbol("STOP_$(H)"))
                                        )
        end
    else
        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"
    end

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
                       system_formulation::Type{<:PM.AbstractPowerModel}) where D<:AbstractHydroDispatchFormulation

    add_to_cost(canonical,
                devices,
                Symbol("P_HydroDispatch"),
                :fixed,
                -1.0)

    return

end

##################################### Water/Energy Budget Constraint ############################
function _get_budget(canonical::Canonical,
                    devices::IS.FlattenIteratorWrapper{H})
    
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
                            budget_data::Vector{Tuple{String, Int64, Float64, Float64}},
                            cons_name::Symbol,
                            param_reference::UpdateRef,
                            var_name::Symbol)

    time_steps = model_time_steps(canonical)
    variable = get_variable(canonical, var_name)
    set_name = (r[1] for r in budget_data)
    constraint = _add_cons_container!(canonical, cons_name, set_name, 1) 
    param = _add_param_container!(canonical, param_reference, names, 1)

    for data in budget_data
        name = data[1]
        forecast = data[4][t]
        multiplier = data[3]
        param[name] = PJ.add_parameter(canonical.JuMPmodel, forecast)
        constraint[name] = JuMP.@constraint(canonical.JuMPmodel,
                    sum([variable[name, t] for t in 1:time_steps]) <= multiplier*param[name])
    end

    return

end


function device_budget_ub(canonical::Canonical,
                            budget_data::Vector{Tuple{String, Int64, Float64, Float64}},
                            cons_name::Symbol,
                            var_name::Symbol)

    time_steps = model_time_steps(canonical)
    variable = get_variable(canonical, var_name)
    set_name = (r[1] for r in budget_data)
    constraint = _add_cons_container!(canonical, cons_name, set_name, 1) 

    for data in budget_data
        name = data[1]
        forecast = data[4][t]
        multiplier = data[3]
        constraint[name] = JuMP.@constraint(canonical.JuMPmodel,
                    sum([variable[name, t] for t in 1:time_steps]) <= multiplier*forecast)
    end

    return

end
