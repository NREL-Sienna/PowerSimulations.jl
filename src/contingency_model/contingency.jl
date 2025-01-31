#! format: off
get_parameter_type(::Type{<:PSY.Outage}, ::EventModel, ::Type{<:PSY.Device}) = AvailableStatusParameter
# This value could change depending on the event modeling choices
get_parameter_multiplier(::EventParameter, ::PSY.Device, ::EventModel) = 1.0
get_parameter_multiplier(::AvailableStatusParameter, d::PSY.Device, ::EventModel) = PSY.get_max_active_power(d)
get_initial_parameter_value(::AvailableStatusChangeParameter, ::PSY.Device, ::EventModel) = 0.0
get_initial_parameter_value(::AvailableStatusParameter, ::PSY.Device, ::EventModel) = 1.0
#! format: on
