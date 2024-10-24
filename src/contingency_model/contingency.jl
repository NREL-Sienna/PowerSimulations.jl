#! format: off
get_parameter_type(::Type{<:PSY.Outage}, ::Type{<:AbstractEventModel}, ::Type{<:PSY.Device}) = AvailableStatusParameter
get_parameter_multiplier(::AvailableStatusParameter, ::PSY.Device, ::AbstractDeviceFormulation) = 1.0
#! format: on
