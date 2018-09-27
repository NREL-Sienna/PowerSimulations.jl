function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.RenewableGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    devices = [d for d in sys.generators.renewable if (d.available == true && !isa(d, PowerSystems.RenewableFix))]

    p_re = activepowervariables(m, devices, sys.time_periods);

    if !isempty(devices)

        varnetinjectiterate!(netinjection.var_active, p_re, sys.time_periods, devices)

        activepower(m, devices, category_formulation, system_formulation, sys.time_periods)

        cost = variablecost(m, devices, category_formulation, system_formulation)

        add_to_cost!(m, cost)

    end

end
