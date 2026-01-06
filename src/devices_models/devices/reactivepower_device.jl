#! format: off

requires_initialization(::AbstractReactivePowerDeviceFormulation) = false
get_variable_multiplier(_, ::Type{<:PSY.SynchronousCondenser}, ::AbstractReactivePowerDeviceFormulation) = 1.0

############## ReactivePowerVariable, SynchronousCondensers ####################
get_variable_binary(::ReactivePowerVariable, ::Type{PSY.SynchronousCondenser}, ::AbstractReactivePowerDeviceFormulation) = false
get_variable_warm_start_value(::ReactivePowerVariable, d::PSY.SynchronousCondenser, ::AbstractReactivePowerDeviceFormulation) = PSY.get_reactive_power(d)
get_variable_lower_bound(::ReactivePowerVariable, d::PSY.SynchronousCondenser, ::AbstractReactivePowerDeviceFormulation) = isnothing(PSY.get_reactive_power_limits(d)) ? nothing : PSY.get_reactive_power_limits(d).min
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.SynchronousCondenser, ::AbstractReactivePowerDeviceFormulation) = isnothing(PSY.get_reactive_power_limits(d)) ? nothing : PSY.get_reactive_power_limits(d).max

#! format: on
function get_initial_conditions_device_model(
    model::OperationModel,
    ::DeviceModel{T, D},
) where {T <: PSY.SynchronousCondenser, D <: AbstractReactivePowerDeviceFormulation}
    return DeviceModel(T, SynchronousCondenserBasicDispatch)
end

function get_default_attributes(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.SynchronousCondenser, V <: AbstractReactivePowerDeviceFormulation}
    return Dict{String, Any}()
end

function get_default_time_series_names(
    ::Type{<:PSY.SynchronousCondenser},
    ::Type{<:AbstractReactivePowerDeviceFormulation},
)
    return Dict{Type{<:TimeSeriesParameter}, String}()
end
