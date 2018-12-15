function constructdevice!(m::JuMP.AbstractModel, netinjection::BalanceNamedTuple, category::Type{PSY.RenewableGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    dev_set = [a.second for a in args if a.first == :devices]

    isempty(dev_set) ? devices = [d for d in sys.generators.renewable if (d.available == true && !isa(d, PSY.RenewableFix))] : devices = dev_set[1]

    p_re = activepowervariables(m, devices, sys.time_periods);

    if !isempty(devices)

        varnetinjectiterate!(netinjection.var_active, p_re, sys.time_periods, devices)

        activepower(m, devices, category_formulation, system_formulation, sys.time_periods)

        cost = variablecost(m, devices, category_formulation, system_formulation)

        add_to_cost!(m, cost)

    end

end


function constructdevice!(m::JuMP.AbstractModel, netinjection::BalanceNamedTuple, category::Type{PSY.RenewableGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    dev_set = [d for d in sys.generators.renewable if (d.available == true && !isa(d, PSY.RenewableFix))]

    if !isempty(dev_set)

        constructdevice!(m, netinjection, category, category_formulation, PM.AbstractPowerFormulation, sys; devices = dev_set)

        dev_set_q = [d for d in dev_set if (d.tech.reactivepowerlimits != nothing)]

        if !isempty(setdiff(dev_set,dev_set_q)) @warn "Some devices have no defined reactive injection capabilities and will not create q_re variables and constraints"  end

        q_re = reactivepowervariables(m, dev_set_q, sys.time_periods);

        varnetinjectiterate!(netinjection.var_reactive, q_re, sys.time_periods, dev_set_q)

        m = reactivepower(m, dev_set_q, category_formulation, system_formulation, sys.time_periods)

    end

end
