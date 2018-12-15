###Dispatch Formulations##

"""
This function creates the minimal themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function constructdevice!(ps_m::CanonicalModel, netinjection::BalanceNamedTuple, category::Type{PSY.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {D <: AbstractThermalDispatchForm, S <: PM.AbstractActivePowerFormulation}

    activepowervariables(ps_m, sys.generators.thermal, sys.time_periods);

    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    cost = variablecost(ps_m, sys.generators.thermal, category_formulation, system_formulation)

    add_to_cost!(ps_m, cost)

end


function constructdevice!(ps_m::CanonicalModel, netinjection::BalanceNamedTuple, category::Type{PSY.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    constructdevice!(ps_m, netinjection, category, category_formulation, PM.AbstractActivePowerFormulation, sys; kwargs...)

    reactivepowervariables(ps_m, sys.generators.thermal, sys.time_periods);

    reactivepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

end


function constructdevice!(ps_m::CanonicalModel, netinjection::BalanceNamedTuple, category::Type{PSY.ThermalGen}, category_formulation::Type{ThermalRampLimitDispatch}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: PM.AbstractPowerFormulation}

    constructdevice!(ps_m, netinjection, category, AbstractThermalDispatchForm, PM.AbstractPowerFormulation, sys; kwargs...)

    #rampargs = pairs((;(k=>v for (k,v) in pairs(args) if k in [:initalpower])...))

    rampconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

end


###Commitment Formulations##

"""
This function creates the minimal the minimal thermal commitment formulation
"""
function constructdevice!(ps_m::CanonicalModel, netinjection::BalanceNamedTuple, category::Type{PSY.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {D <: AbstractThermalCommitmentForm, S <: PM.AbstractActivePowerFormulation}

    p_th = activepowervariables(ps_m, sys.generators.thermal, sys.time_periods);

    commitmentvariables(ps_m, sys.generators.thermal, sys.time_periods)

    activepower(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    variable_cost = variablecost(ps_m, sys.generators.thermal, AbstractThermalDispatchForm, system_formulation)

    commitment_cost = commitmentcost(ps_m, sys.generators.thermal, category_formulation, system_formulation)

    add_to_cost!(ps_m, variable_cost)

    add_to_cost!(ps_m, commitment_cost)

end


"""
This function adds constraints to the minimal thermal commitment formulation
"""
function constructdevice!(ps_m::CanonicalModel, netinjection::BalanceNamedTuple, category::Type{PSY.ThermalGen}, category_formulation::Type{StandardThermalCommitment}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: PM.AbstractActivePowerFormulation}

    constructdevice!(ps_m, netinjection, category, AbstractThermalCommitmentForm, PM.AbstractActivePowerFormulation, sys; kwargs...)

    #commitargs = pairs((;(k=>v for (k,v) in pairs(args) if k in [:initalstatus,:initialonduration,:initialoffduration])...)) #this isn't strictly needed, could delete for cleanliness

    commitmentconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    #rampargs = pairs((;(k=>v for (k,v) in pairs(args) if k in [:initalpower])...)) #this isn't strictly needed, could delete for cleanliness

    rampconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

    timeconstraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods; kwargs...)

end

"""
This function adds constraints to the minimal thermal commitment formulation
"""
function constructdevice!(ps_m::CanonicalModel, netinjection::BalanceNamedTuple, category::Type{PSY.ThermalGen}, category_formulation::Type{StandardThermalCommitment}, system_formulation::Type{CopperPlatePowerModel}, sys::PSY.PowerSystem; kwargs...)

    constructdevice!(ps_m, netinjection, category, category_formulation, PM.AbstractActivePowerFormulation, sys; kwargs...)

end

