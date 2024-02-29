"""
Auxiliary Variable for Thermal Generation Models to keep track of time elapsed on
"""
struct TimeDurationOn <: IS.AuxVariableType end

"""
Auxiliary Variable for Thermal Generation Models to keep track of time elapsed off
"""
struct TimeDurationOff <: IS.AuxVariableType end

"""
Auxiliary Variable for Thermal Generation Models that solve for power above min
"""
struct PowerOutput <: IS.AuxVariableType end

should_write_resulting_value(::Type{<:IS.AuxVariableType}) = true

convert_result_to_natural_units(::Type{<:IS.AuxVariableType}) = false
convert_result_to_natural_units(::Type{PowerOutput}) = true
