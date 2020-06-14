abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end
abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end
abstract type AbstractHydroUnitCommitment <: AbstractHydroFormulation end
abstract type AbstractHydroReservoirFormulation <: AbstractHydroDispatchFormulation end
struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end
struct HydroDispatchReservoirFlow <: AbstractHydroReservoirFormulation end
struct HydroDispatchReservoirStorage <: AbstractHydroReservoirFormulation end
#=
# Commenting out all Unit Commitment formulations as all Hydro UC
# formulations are currently not supported
struct HydroCommitmentRunOfRiver <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirFlow <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirStorage <: AbstractHydroUnitCommitment end
=#
########################### Hydro generation variables #################################
function activepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
) where {H <: PSY.HydroGen}
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, H),
        false,
        :nodal_balance_active;
        lb_value = d -> PSY.get_activepowerlimits(d).min,
        ub_value = d -> PSY.get_activepowerlimits(d).max,
        init_value = d -> PSY.get_activepower(d),
    )

    return
end

function reactivepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
) where {H <: PSY.HydroGen}
    add_variable(
        psi_container,
        devices,
        variable_name(REACTIVE_POWER, H),
        false,
        :nodal_balance_reactive;
        ub_value = d -> PSY.get_reactivepowerlimits(d).max,
        lb_value = d -> PSY.get_reactivepowerlimits(d).min,
        init_value = d -> PSY.get_reactivepower(d),
    )

    return
end

function energy_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
) where {H <: PSY.HydroGen}
    add_variable(
        psi_container,
        devices,
        variable_name(ENERGY, H),
        false;
        ub_value = d -> PSY.get_storage_capacity(d),
        lb_value = d -> 0.0,
        init_value = d -> PSY.get_initial_storage(d),
    )

    return
end

#=
function inflow_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
) where {H <: PSY.HydroGen}
    add_variable(
        psi_container,
        devices,
        variable_name(INFLOW, H),
        false;
        ub_value = d -> PSY.get_inflow(d),
        lb_value = d -> 0.0,
    )

    return
end
=#

function spillage_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
) where {H <: PSY.HydroGen}
    add_variable(
        psi_container,
        devices,
        variable_name(SPILLAGE, H),
        false;
        lb_value = d -> 0.0,
    )

    return
end

"""
This function add the variables for power generation commitment to the model
"""
#=
function commitment_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
) where {H <: PSY.HydroGen}
    time_steps = model_time_steps(psi_container)
    var_names = [variable_name(ON, H), variable_name(START, H), variable_name(STOP, H)]

    for v in var_names
        add_variable(psi_container, devices, v, true)
    end

    return
end

# All Hydro UC formulations are currently not supported
### Constraints for Thermal Generation without commitment variables ####
"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H,D},
    system_formulation::Type{S},
    feedforward::Union{Nothing,AbstractAffectFeedForward},
) where {H<:PSY.HydroGen,D<:AbstractHydroUnitCommitment,S<:PM.AbstractPowerModel}
    device_commitment(
        psi_container,
        get_initial_conditions(psi_container, ICKey(DeviceStatus, H)),
        constraint_name(COMMITMENT, H),
        (variable_name(START, H), variable_name(STOP, H), variable_name(ON, H)),
    )

    return
end
=#
####################################### Reactive Power Constraints #########################
function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, D},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HydroGen, D <: AbstractHydroDispatchFormulation}
    constraint_data = Vector{DeviceRange}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = PSY.get_reactivepowerlimits(d)
        name = PSY.get_name(d)
        range_data = DeviceRange(name, limits)
        constraint_data[ix] = range_data
    end

    device_range(
        psi_container,
        constraint_data,
        constraint_name(REACTIVE_RANGE, H),
        variable_name(REACTIVE_POWER, H),
    )
    return
end

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, <:AbstractHydroDispatchFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HydroGen}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !parameters && !use_forecast_data
        constraint_data = Vector{DeviceRange}(undef, length(devices))
        for (ix, d) in enumerate(devices)
            name = PSY.get_name(d)
            ub = PSY.get_activepower(d)
            limits = (min = 0.0, max = ub)
            range_data = DeviceRange(name, limits)
            add_device_services!(range_data, d, model)
            constraint_data[ix] = range_data
        end
        device_range(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(ACTIVE_POWER, H),
        )
        return
    end

    forecast_label = "get_rating"
    constraint_data = Vector{DeviceTimeSeries}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        timeseries_data = DeviceTimeSeries(d, x -> PSY.get_rating(x), ts_vector)
        add_device_services!(timeseries_data, d, model)
        constraint_data[ix] = timeseries_data
    end

    if parameters
        device_timeseries_param_ub(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE, H),
            UpdateRef{H}(ACTIVE_POWER, forecast_label),
            variable_name(ACTIVE_POWER, H),
        )
    else
        device_timeseries_ub(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE, H),
            variable_name(ACTIVE_POWER, H),
        )
    end
    return
end

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, <:AbstractHydroReservoirFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HydroGen}
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
        constraint_name(ACTIVE_RANGE, H),
        variable_name(ACTIVE_POWER, H),
    )
    return
end

#=
# All Hydro UC formulations are currently not supported
function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H,<:AbstractHydroUnitCommitment},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing,AbstractAffectFeedForward},
) where {H<:PSY.HydroGen}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_active, constraint_data = get_time_series(
        psi_container,
        devices,
        model,
        x -> PSY.get_activepowerlimits(x),
    )

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
=#
######################## Inflow constraints ############################
#=
# TODO: Determine if this is useful for ROR formulation ?
function inflow_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H,<:AbstractHydroDispatchFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing,AbstractAffectFeedForward},
) where {H<:PSY.HydroGen}

    return
end

function inflow_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{PSY.HydroEnergyReservoir,HydroDispatchReservoirStorage},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing,AbstractAffectFeedForward},
) where {H<:PSY.HydroGen}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_inflow, constraint_data = _get_inflow_time_series(
        psi_container,
        devices,
        model,
        x -> (min = 0.0, max = PSY.get_inflow(x)),
    )

    if !parameters && !use_forecast_data
        device_range(
            psi_container,
            constraint_data,
            constraint_name(INFLOW_RANGE, H),
            variable_name(INFLOW, H),
        )
        return
    end

    if parameters
        device_timeseries_param_ub(psi_container,
                            ts_data_inflow,
                            constraint_name(INFLOW_RANGE, H),
                            UpdateRef{H}(INFLOW_RANGE, "get_inflow"),
                            variable_name(INFLOW, H))
    else
        device_timeseries_ub(
            psi_container,
            ts_data_inflow,
            constraint_name(INFLOW_RANGE, H),
            variable_name(INFLOW, H),
        )
    end

    return
end
=#
######################## Energy balance constraints ############################

function energy_balance_constraint!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, HydroDispatchReservoirStorage},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HydroEnergyReservoir}
    key = ICKey(EnergyLevel, H)
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !has_initial_conditions(psi_container.initial_conditions, key)
        throw(IS.DataFormatError("Initial Conditions for $(H) Energy Constraints not in the model"))
    end

    forecast_label = "get_inflow"
    constraint_data = Vector{DeviceTimeSeries}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        timeseries_data = DeviceTimeSeries(d, x -> PSY.get_rating(x), ts_vector)
        add_device_services!(timeseries_data, d, model)
        constraint_data[ix] = timeseries_data
    end

    if parameters
        energy_balance_external_input_param(
            psi_container,
            get_initial_conditions(psi_container, key),
            constraint_data,
            constraint_name(ENERGY_CAPACITY, H),
            (
                variable_name(SPILLAGE, H),
                variable_name(ACTIVE_POWER, H),
                variable_name(ENERGY, H),
            ),
            UpdateRef{H}(INFLOW, forecast_label),
        )
    else
        energy_balance_external_input(
            psi_container,
            get_initial_conditions(psi_container, key),
            constraint_data,
            constraint_name(ENERGY_CAPACITY, H),
            (
                variable_name(SPILLAGE, H),
                variable_name(ACTIVE_POWER, H),
                variable_name(ENERGY, H),
            ),
        )
    end
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::Type{<:AbstractHydroUnitCommitment},
) where {H <: PSY.HydroGen}
    status_init(psi_container.initial_conditions, devices)
    output_init(psi_container.initial_conditions, devices)
    duration_init(psi_container.initial_conditions, devices)

    return
end

function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::Type{D},
) where {H <: PSY.HydroGen, D <: AbstractHydroDispatchFormulation}
    output_init.initial_conditions_container(psi_container, devices)

    return
end

########################## Addition of to the nodal balances ###############################
function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    system_formulation::Type{<:PM.AbstractPowerModel},
) where {H <: PSY.HydroGen}
    nodal_expression!(psi_container, devices, PM.AbstractActivePowerModel)
    # Commented out since PF = 1.0 is the assumtion for RoR Hydro
    #=
     parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    if parameters
     forecast_label = "get_rating"
     peak_value_function = x -> PSY.get_rating(x) * sin(acos(PSY.get_powerfactor(x)))
    else
     forecast_label = "get_rating"
     peak_value_function = x -> PSY.get_reactivepower(x)
    end
    constraint_data = Vector{DeviceTimeSeries}(undef, length(devices))
    for (ix, d) in enumerate(devices)
     ts_vector = get_time_series(psi_container, d, forecast_label)
     timeseries_data = DeviceTimeSeries(d, peak_value_function, ts_vector)
     constraint_data[ix] = timeseries_data
    end
    
    if parameters
     include_parameters(
         psi_container,
         constraint_data,
         UpdateRef{R}(REACTIVE_POWER, forecast_label),
         :nodal_balance_active,
     )
     return
    else
     for t in model_time_steps(psi_container)
         for device in constraint_data
             add_to_expression!(
                 psi_container.expressions[:nodal_balance_reactive],
                 device.bus_number,
                 t,
                 device.multiplier * device.timeseries[t],
             )
         end
     end
    end
    return
    =#
end

function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    system_formulation::Type{<:PM.AbstractActivePowerModel},
) where {H <: PSY.HydroGen}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    if use_forecast_data
        forecast_label = "get_rating"
        peak_value_function = x -> PSY.get_rating(x)
    else
        forecast_label = ""
        peak_value_function = x -> PSY.get_activepower(x)
    end
    constraint_data = Vector{DeviceTimeSeries}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        timeseries_data = DeviceTimeSeries(d, peak_value_function, ts_vector)
        constraint_data[ix] = timeseries_data
    end

    if parameters
        include_parameters(
            psi_container,
            constraint_data,
            UpdateRef{H}(ACTIVE_POWER, forecast_label),
            :nodal_balance_active,
        )
        return
    else
        for t in model_time_steps(psi_container)
            for device in constraint_data
                add_to_expression!(
                    psi_container.expressions[:nodal_balance_active],
                    device.bus_number,
                    t,
                    device.multiplier * device.timeseries[t],
                )
            end
        end
    end
    return
end

##################################### Hydro generation cost ############################
function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.HydroEnergyReservoir},
    device_formulation::Type{D},
    system_formulation::Type{<:PM.AbstractPowerModel},
) where {D <: AbstractHydroFormulation}
    add_to_cost(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, PSY.HydroEnergyReservoir),
        :fixed,
        -1.0,
    )

    return
end

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::Type{D},
    system_formulation::Type{<:PM.AbstractPowerModel},
) where {D <: AbstractHydroFormulation, H <: PSY.HydroGen}

    return
end

##################################### Water/Energy Limit Constraint ############################
function energy_limit_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, <:AbstractHydroDispatchFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::IntegralLimitFF,
) where {H <: PSY.HydroGen}
    return
end

function energy_limit_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, <:AbstractHydroDispatchFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HydroGen}

    forecast_label = "get_storage_capacity"
    constraint_data = Vector{DeviceTimeSeries}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        timeseries_data = DeviceTimeSeries(d, x -> PSY.get_rating(x), ts_vector)
        add_device_services!(timeseries_data, d, model)
        constraint_data[ix] = timeseries_data
    end

    if model_has_parameters(psi_container)
        device_energy_limit_param_ub(
            psi_container,
            constraint_data,
            constraint_name(ENERGY_LIMIT, H),
            UpdateRef{H}(ENERGY_BUDGET, forecast_label),
            variable_name(ACTIVE_POWER, H),
        )
    else
        device_energy_limit_ub(
            psi_container,
            constraint_data,
            constraint_name(ENERGY_LIMIT),
            variable_name(ACTIVE_POWER, H),
        )
    end
end

function device_energy_limit_param_ub(
    psi_container::PSIContainer,
    energy_limit_data::Vector{DeviceTimeSeries},
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    set_name = (r.name for r in energy_limit_data)
    constraint = add_cons_container!(psi_container, cons_name, set_name)
    container = add_param_container!(psi_container, param_reference, set_name, 1)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)
    for data in energy_limit_data
        name = data.name
        multiplier[name, 1] = data.multiplier
        param[name, 1] = PJ.add_parameter(psi_container.JuMPmodel, sum(data.timeseries))
        constraint[name] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum([variable[name, t] for t in time_steps]) <= multiplier[name, 1] * param[name, 1]
        )
    end

    return
end

function device_energy_limit_ub(
    psi_container::PSIContainer,
    energy_limit_data::Vector{DeviceTimeSeries},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    names = (r.name for r in energy_limit_data)
    constraint = add_cons_container!(psi_container, cons_name, names)

    for data in energy_limit_data
        name = data.name
        forecast = data.timeseries
        multiplier = data.multiplier
        constraint[name] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum([variable[name, t] for t in time_steps]) <= multiplier * sum(forecast)
        )
    end

    return
end
