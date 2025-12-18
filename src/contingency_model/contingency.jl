#! format: off
# This value could change depending on the event modeling choices
get_parameter_multiplier(::EventParameter, ::PSY.Device, ::EventModel) = 1.0
get_initial_parameter_value(::ActivePowerOffsetParameter, ::PSY.Device, ::EventModel) = 0.0
get_initial_parameter_value(::ReactivePowerOffsetParameter, ::PSY.Device, ::EventModel) = 0.0
get_initial_parameter_value(::AvailableStatusChangeCountdownParameter, ::PSY.Device, ::EventModel) = 0.0
get_initial_parameter_value(::AvailableStatusParameter, ::PSY.Device, ::EventModel) = 1.0

supports_outages(::Type{T}) where {T <: PSY.StaticInjection} = false
supports_outages(::Type{T}) where {T <: PSY.ThermalStandard} = true
supports_outages(::Type{T}) where {T <: PSY.RenewableGen} = true
supports_outages(::Type{T}) where {T <: PSY.ElectricLoad} = true
supports_outages(::Type{T}) where {T <: PSY.Storage} = true
supports_outages(::Type{T}) where {T <: PSY.HydroGen} = true
#! format: on
