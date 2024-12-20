#! format: off
get_parameter_type(::Type{<:PSY.Outage}, ::EventModel, ::Type{<:PSY.Device}) = AvailableStatusParameter
# This value could change depending on the event modeling choices
get_parameter_multiplier(::EventParameter, ::PSY.Device, ::EventModel) = 1.0
#! format: on
