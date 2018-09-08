function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_model::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem) where {D <: AbstractDispatchForm, S <: AbstractDCPowerModel}

    pth = activepowervariables(m, sys.generators.thermal, sys.time_periods);

    netinjection = varnetinjectiterate!(netinjection.var_active, pth, sys.time_periods, sys.generators.thermal)

    constraints = [activepower]

        for c in constraints

            m = c(m, sys.generators.thermal, category_model, system_formulation, sys.time_periods)

        end

    return m, netinjection

end

function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ThermalGen}, category_model::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem) where {D <: AbstractUnitCommitmentForm, S <: AbstractDCPowerModel}

    pth = activepowervariables(m, sys.generators.thermal, sys.time_periods);

    on_thermal, start_thermal, stop_thermal = commitmentvariables(m, sys.generators.thermal, sys.time_periods)

    netinjection = varnetinjectiterate!(netinjection.var_active, pth, sys.time_periods, sys.generators.thermal)

    constraints = [activepower]

    for c in constraints

        m = c(m, sys.generators.thermal, category_model, system_formulation, sys.time_periods)

    end

    return m, netinjection

end
