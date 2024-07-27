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

"""
Auxiliary Variable of DC Current Variables for DC Lines formulations

Docs abbreviation: ``i_l^{dc}``
"""
struct DCLineCurrent <: AuxVariableType end

"""
Auxiliary Variable of DC Current Variables for DC Lines formulations

Docs abbreviation: ``p_l^{loss}``
"""
struct DCLineLosses <: AuxVariableType end

convert_result_to_natural_units(::Type{PowerOutput}) = true
