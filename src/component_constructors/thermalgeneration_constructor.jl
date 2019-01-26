###Dispatch Formulations##

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function constructdevice!(ps_m::CanonicalModel, category::Type{T}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods

    #Variables
    activepowervariables(ps_m, sys.generators.thermal, time_range);

    reactivepowervariables(ps_m, sys.generators.thermal, time_range);

    commitmentvariables(ps_m, sys.generators.thermal, time_range)

    #Constraints
    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    reactivepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    if :initial_conditions in keys(kwargs)

        initial_conditions = kwargs[:initial_conditions]

    else

        initial_conditions = [(g.name, Float64(g.tech.activepower > 0.0)) for g in sys.generators.thermal]

    end

    commitmentconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range, initial_conditions)

    #rampconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #timeconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #rating constraints

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end


function constructdevice!(ps_m::CanonicalModel, category::Type{T}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractActivePowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods

    #Variables
    activepowervariables(ps_m, sys.generators.thermal, time_range);

    commitmentvariables(ps_m, sys.generators.thermal, time_range)

    #Constraints
    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    if :initial_conditions in keys(kwargs)

        initial_conditions = kwargs[:initial_conditions]

    else

        initial_conditions = [(g.name, Float64(g.tech.activepower > 0.0)) for g in sys.generators.thermal]

    end

    commitmentconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range, initial_conditions)

    #rampconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #timeconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end

function constructdevice!(ps_m::CanonicalModel, category::Type{T}, category_formulation::Type{PSI.ThermalDispatch}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {T<: PSY.ThermalGen, S <: PM.AbstractPowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods

    #Variables
    activepowervariables(ps_m, sys.generators.thermal, time_range);

    reactivepowervariables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    reactivepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    #rating constraints

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end

function constructdevice!(ps_m::CanonicalModel, category::Type{T}, category_formulation::Type{PSI.ThermalDispatch}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {T<: PSY.ThermalGen, S <: PM.AbstractActivePowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods

    #Variables
    activepowervariables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end