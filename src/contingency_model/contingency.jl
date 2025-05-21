#! format: off
get_parameter_type(::Type{<:PSY.Outage}, ::EventModel, ::Type{<:PSY.Device}) = AvailableStatusParameter
# This value could change depending on the event modeling choices
get_parameter_multiplier(::EventParameter, ::PSY.Device, ::EventModel) = 1.0
get_initial_parameter_value(::ActivePowerOffsetParameter, ::PSY.Device, ::EventModel) = 0.0
get_initial_parameter_value(::ReactivePowerOffsetParameter, ::PSY.Device, ::EventModel) = 0.0
get_initial_parameter_value(::AvailableStatusChangeCountdownParameter, ::PSY.Device, ::EventModel) = 0.0
get_initial_parameter_value(::AvailableStatusParameter, ::PSY.Device, ::EventModel) = 1.0
#! format: on
