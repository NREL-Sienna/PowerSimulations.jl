############## EnergySlackUp, Storage ####################

get_variable_binary(::EnergySlackUp, ::Type{<:PSY.Component}) = false
get_variable_lower_bound(::EnergySlackUp, d::PSY.Component, _) = 0.0

############## EnergySlackDown, Storage ####################

get_variable_binary(::EnergySlackDown, ::Type{<:PSY.Component}) = false
get_variable_upper_bound(::EnergySlackDown, d::PSY.Component, _) = 0.0



get_target_multiplier(v::PSY.HydroEnergyReservoir) =  PSY.get_storage_capacity(v)
get_target_multiplier(v::PSY.BatteryEMS) = PSY.get_rating(v)

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
) where {
    T <: PSY.Component,
    S <: AbstractDeviceFormulation,
}
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
            ts_vector_target = length(time_steps) == 1 ? [PSY.get_storage_target(d)] : 
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
                make_variable_name(ENERGY_SLACK_UP, T),
                make_variable_name(ENERGY_SLACK_DN, T),
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
                make_variable_name(ENERGY_SLACK_UP, T),
                make_variable_name(ENERGY_SLACK_DN, T),
            ),
        )
    end
    return
end

###################


# function cost_function!(
#     optimization_container::OptimizationContainer,
#     devices::IS.FlattenIteratorWrapper{T},
#     ::DeviceModel{T, U},
#     ::Type{<:PM.AbstractPowerModel},
#     feedforward::Union{Nothing, AbstractAffectFeedForward} = nothing,
# ) where {
#     T <: PSY.Component,
#     U <: Union{
#         HydroDispatchReservoirStorage,
#         HydroCommitmentReservoirStorage,
#         EndOfPeriodEnergyTarget,
#     },
# }
#     for d in devices
#         spec = AddCostSpec(T, U, optimization_container)
#         add_to_cost!(optimization_container, spec, spec.variable_cost(d), d)
#     end
#     return
# end
