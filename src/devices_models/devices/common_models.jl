function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{EnergyShortageVariable},
    ::Type{T},
    ::Type{<:AbstractDeviceFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.Component}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RangeConstraint,
                EnergyShortageVariable,
                T,
            ),
            variable_name = make_variable_name(EnergyShortageVariable, T),
            limits_func = x -> (
                min = 0.0,
                max = PSY.get_energy_shortage_cost(PSY.get_operation_cost(x)) * M_VALUE,
            ),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

"""
This function defines the constraints for the water level (or state of charge)
for the Hydro Reservoir.
"""
function energy_target_constraint!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, S},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.Component, S <: AbstractDeviceFormulation}
    key = ICKey(EnergyLevel, T)
    parameters = model_has_parameters(optimization_container)
    use_forecast_data = model_uses_forecasts(optimization_container)
    time_steps = model_time_steps(optimization_container)
    target_forecast_label = "storage_target"
    constraint_infos_target = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    if use_forecast_data
        for (ix, d) in enumerate(devices)
            ts_vector_target =
                get_time_series(optimization_container, d, target_forecast_label)
            constraint_info_target = DeviceTimeSeriesConstraintInfo(
                d,
                x -> get_target_multiplier(x),
                ts_vector_target,
            )
            constraint_infos_target[ix] = constraint_info_target
        end
    else
        for (ix, d) in enumerate(devices)
            ts_vector_target =
                length(time_steps) == 1 ? [PSY.get_storage_target(d)] :
                vcat(zeros(time_steps[end - 1]), PSY.get_storage_target(d))
            constraint_info_target = DeviceTimeSeriesConstraintInfo(
                d,
                x -> get_target_multiplier(x),
                ts_vector_target,
            )
            constraint_infos_target[ix] = constraint_info_target
        end
    end

    if parameters
        energy_target_param!(
            optimization_container,
            constraint_infos_target,
            make_constraint_name(ENERGY_TARGET, T),
            (
                make_variable_name(ENERGY, T),
                make_variable_name(ENERGY_SHORTAGE, T),
                make_variable_name(ENERGY_SURPLUS, T),
            ),
            UpdateRef{T}(TARGET, target_forecast_label),
        )
    else
        energy_target!(
            optimization_container,
            constraint_infos_target,
            make_constraint_name(ENERGY_TARGET, T),
            (
                make_variable_name(ENERGY, T),
                make_variable_name(ENERGY_SHORTAGE, T),
                make_variable_name(ENERGY_SURPLUS, T),
            ),
        )
    end
    return
end
