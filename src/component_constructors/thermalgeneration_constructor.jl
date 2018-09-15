###Dispatch Formulations##

"""
This function creates the minimal themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    p_th = activepowervariables(m, sys.generators.thermal, sys.time_periods);

    varnetinjectiterate!(netinjection.var_active, p_th, sys.time_periods, sys.generators.thermal)

    activepower(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    cost = variablecost(m, sys.generators.thermal, category_formulation, system_formulation)

    add_to_cost!(m, cost)

end


function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {D <: AbstractThermalDispatchForm, S <: AbstractACPowerModel}

    constructdevice!(m, netinjection, category, category_formulation, PM.AbstractPowerFormulation, sys)

    qth = reactivepowervariables(m, sys.generators.thermal, sys.time_periods);

    varnetinjectiterate!(netinjection.var_reactive, qth, sys.time_periods, sys.generators.thermal)

    m = reactivepower(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

end


function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{RampLimitDispatch}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: AbstractDCPowerModel}

    m, netinjection = constructdevice!(m, netinjection, category, category_formulation, PM.AbstractPowerFormulation, sys)

    rampconstraints(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    return m, netinjection

end


###Commitment Formulations##

"""
This function creates the minimal the minimal thermal commitment formulation
"""
function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {D <: AbstractThermalCommitmentForm, S <: AbstractDCPowerModel}

    p_th = activepowervariables(m, sys.generators.thermal, sys.time_periods);

    commitmentvariables(m, sys.generators.thermal, sys.time_periods)

    varnetinjectiterate!(netinjection.var_active, p_th, sys.time_periods, sys.generators.thermal)

    activepower(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    variable_cost = variablecost(m, sys.generators.thermal, AbstractThermalDispatchForm, system_formulation)

    commitment_cost = commitmentcost(m, sys.generators.thermal, category_formulation, system_formulation)

    add_to_cost!(m, variable_cost)

    add_to_cost!(m, commitment_cost)

end


"""
This function adds constraints to the minimal thermal commitment formulation
"""
function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{StandardThermalCommitment}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: AbstractDCPowerModel}

    m, netinjection = constructdevice!(m, netinjection, category, AbstractThermalCommitmentForm, AbstractDCPowerModel, sys)

    commitmentconstraints(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    rampconstraints(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

    timeconstraints(m, sys.generators.thermal, category_formulation, system_formulation, sys.time_periods)

end

"""
This function adds constraints to the minimal thermal commitment formulation
"""
function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_formulation::Type{StandardThermalCommitment}, system_formulation::Type{CopperPlatePowerModel}, sys::PowerSystems.PowerSystem; kwargs...)

    constructdevice!(m, netinjection, category, category_formulation, AbstractDCPowerModel, sys)

end

