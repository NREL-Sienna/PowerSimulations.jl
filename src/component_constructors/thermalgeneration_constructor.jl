###Dispatch Formulations##

"""
This function creates the minimal themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    pth = activepowervariables(m, sys.generators.thermal, sys.time_periods);

   varnetinjectiterate!(netinjection.var_active, pth, sys.time_periods, sys.generators.thermal)

    m = activepower(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    return m, netinjection

end


function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {D <: AbstractThermalDispatchForm, S <: AbstractACPowerModel}

    m, netinjection = constructdevice!(m, netinjection, category, category_formulation, PM.AbstractPowerFormulation, sys)

    qth = reactivepowervariables(m, sys.generators.thermal, sys.time_periods);

    varnetinjectiterate!(netinjection.var_reactive, qth, sys.time_periods, sys.generators.thermal)

    m = reactivepower(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    return m, netinjection

end



"""
This function add constraints to the minimal thermal dispatch formulation
"""
function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{RampLimitDispatch}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: AbstractDCPowerModel}

    println("yes")

    m, netinjection = constructdevice!(m, netinjection, category, category_formulation, PM.AbstractPowerFormulation, sys)

    rampconstraints(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    return m, netinjection

end


###Commitment Formulations##

"""
This function creates the minimal the minimal thermal commitment formulation
"""
function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {D <: AbstractThermalCommitmentForm, S <: AbstractDCPowerModel}

    pth = activepowervariables(m, sys.generators.thermal, sys.time_periods);

    commitmentvariables(m, sys.generators.thermal, sys.time_periods)

    #TODO: Add kwargs to include initial conditions

    commitmentconstraints(m, sys.generators.thermal, sys.time_periods)

    netinjection = varnetinjectiterate!(netinjection.var_active, pth, sys.time_periods, sys.generators.thermal)

    activepower(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    return m, netinjection

end


"""
This function adds constraints to the minimal thermal commitment formulation
"""
function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{StandardThermalCommitment}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: AbstractDCPowerModel}

    m, netinjection = constructdevice!(m, netinjection, category, AbstractThermalCommitmentForm, PM.AbstractPowerFormulation, sys)

    rampconstraints(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    return m, netinjection

end
