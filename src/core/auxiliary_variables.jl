"""
Auxiliary Variable for Thermal Generation Models to keep track of time elapsed on
"""
struct TimeDurationOn <: AuxVariableType end

"""
Auxiliary Variable for Thermal Generation Models to keep track of time elapsed off
"""
struct TimeDurationOff <: AuxVariableType end

"""
Auxiliary Variable for Thermal Generation Models that solve for power above min
"""
struct PowerOutput <: AuxVariableType end

should_write_resulting_value(::Type{<:AuxVariableType}) = true

convert_result_to_natural_units(::Type{<:AuxVariableType}) = false
convert_result_to_natural_units(::Type{PowerOutput}) = true
