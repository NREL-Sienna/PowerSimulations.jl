###Dispatch Formulations##

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function constructdevice!(ps_m::CanonicalModel, category::Type{PSY.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    #Variables
    activepowervariables(ps_m, sys.generators.thermal, sys.time_periods);

    reactivepowervariables(ps_m, sys.generators.thermal, sys.time_periods);

    commitmentvariables(ps_m, sys.generators.thermal, sys.time_periods)

    #Constraints
    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    reactivepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    commitmentconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #rampconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #timeconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #rating constraints

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end


function constructdevice!(ps_m::CanonicalModel, category::Type{PSY.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {D <: AbstractThermalFormulation, S <: PM.AbstractActivePowerFormulation}

    #Variables
    activepowervariables(ps_m, sys.generators.thermal, sys.time_periods);

    commitmentvariables(ps_m, sys.generators.thermal, sys.time_periods)

    #Constraints
    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    commitmentconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #rampconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #timeconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end

function constructdevice!(ps_m::CanonicalModel, category::Type{PSY.ThermalGen}, category_formulation::Type{PSI.ThermalDispatch}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: PM.AbstractPowerFormulation}

    #Variables
    activepowervariables(ps_m, sys.generators.thermal, sys.time_periods);

    reactivepowervariables(ps_m, sys.generators.thermal, sys.time_periods);

    #Constraints
    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    reactivepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    #rating constraints

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end

function constructdevice!(ps_m::CanonicalModel, category::Type{PSY.ThermalGen}, category_formulation::Type{PSI.ThermalDispatch}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: PM.AbstractActivePowerFormulation}

    #Variables
    activepowervariables(ps_m, sys.generators.thermal, sys.time_periods);

    #Constraints
    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end