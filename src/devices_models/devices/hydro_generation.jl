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
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = PSY.get_reactivepowerlimits(d)
        name = PSY.get_name(d)
        constraint_infos[ix] = DeviceRangeConstraintInfo(name, limits)
    end

    device_range(
        psi_container,
        constraint_infos,
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
        constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
        for (ix, d) in enumerate(devices)
            name = PSY.get_name(d)
            ub = PSY.get_activepower(d)
            limits = (min = 0.0, max = ub)
            constraint_info = DeviceRangeConstraintInfo(name, limits)
            add_device_services!(constraint_info, d, model)
            constraint_infos[ix] = constraint_info
        end
        device_range(
            psi_container,
            constraint_infos,
            constraint_name(ACTIVE_RANGE, H),
            variable_name(ACTIVE_POWER, H),
        )
        return
    end

    forecast_label = "get_rating"
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_rating(x), ts_vector)
        add_device_services!(constraint_info.range, d, model)
        constraint_infos[ix] = constraint_info
    end

    if parameters
        device_timeseries_param_ub(
            psi_container,
            constraint_infos,
            constraint_name(ACTIVE, H),
            UpdateRef{H}(ACTIVE_POWER, forecast_label),
            variable_name(ACTIVE_POWER, H),
        )
    else
        device_timeseries_ub(
            psi_container,
            constraint_infos,
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
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_activepowerlimits(d)
        constraint_info = DeviceRangeConstraintInfo(name, limits)
        add_device_services!(constraint_info, d, model)
        constraint_infos[ix] = constraint_info
    end
    device_range(
        psi_container,
        constraint_infos,
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

    ts_data_active, constraint_infos = get_time_series(
        psi_container,
        devices,
        model,
        x -> PSY.get_activepowerlimits(x),
    )

    if !parameters && !use_forecast_data
        device_semicontinuousrange(
            psi_container,
            constraint_infos,
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

    ts_data_inflow, constraint_infos = _get_inflow_time_series(
        psi_container,
        devices,
        model,
        x -> (min = 0.0, max = PSY.get_inflow(x)),
    )

    if !parameters && !use_forecast_data
        device_range(
            psi_container,
            constraint_infos,
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
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_rating(x), ts_vector)
        add_device_services!(constraint_info.range, d, model)
        constraint_infos[ix] = constraint_info
    end

    if parameters
        energy_balance_external_input_param(
            psi_container,
            get_initial_conditions(psi_container, key),
            constraint_infos,
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
            constraint_infos,
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
    status_init(psi_container, devices)
    output_init(psi_container, devices)
    duration_init(psi_container, devices)

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

########################## Addition to the nodal balances #################################

function NodalExpressionInputs(
    ::Type{T},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return NodalExpressionInputs(
        "get_rating",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_rating(x) : x -> PSY.get_activepower(x),
        1.0,
        T
    )
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
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_rating(x), ts_vector)
        add_device_services!(constraint_info.range, d, model)
        constraint_infos[ix] = constraint_info
    end

    if model_has_parameters(psi_container)
        device_energy_limit_param_ub(
            psi_container,
            constraint_infos,
            constraint_name(ENERGY_LIMIT, H),
            UpdateRef{H}(ENERGY_BUDGET, forecast_label),
            variable_name(ACTIVE_POWER, H),
        )
    else
        device_energy_limit_ub(
            psi_container,
            constraint_infos,
            constraint_name(ENERGY_LIMIT),
            variable_name(ACTIVE_POWER, H),
        )
    end
end

function device_energy_limit_param_ub(
    psi_container::PSIContainer,
    energy_limit_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    set_name = (get_name(r) for r in energy_limit_data)
    constraint = add_cons_container!(psi_container, cons_name, set_name)
    container = add_param_container!(psi_container, param_reference, set_name, 1)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)
    for constraint_info in energy_limit_data
        name = get_name(constraint_info)
        multiplier[name, 1] = constraint_info.multiplier
        param[name, 1] =
            PJ.add_parameter(psi_container.JuMPmodel, sum(constraint_info.timeseries))
        constraint[name] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum([variable[name, t] for t in time_steps]) <= multiplier[name, 1] * param[name, 1]
        )
    end

    return
end

function device_energy_limit_ub(
    psi_container::PSIContainer,
    energy_limit_constraints::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    names = (get_name(x) for x in energy_limit_constraints)
    constraint = add_cons_container!(psi_container, cons_name, names)

    for constraint_info in energy_limit_constraints
        name = get_name(constraint_info)
        forecast = constraint_info.timeseries
        multiplier = constraint_info.multiplier
        constraint[name] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum([variable[name, t] for t in time_steps]) <= multiplier * sum(forecast)
        )
    end

    return
end
