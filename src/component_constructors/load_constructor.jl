function constructdevice!(m::JuMP.AbstractModel, netinjection::BalanceNamedTuple, category::Type{L}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {L <: PSY.ElectricLoad, D <: FullControllablePowerLoad, S <: PM.AbstractPowerFormulation}

    dev_set = [a.second for a in args if a.first == :devices]

    isempty(dev_set) ? devices = [d for d in sys.loads if (d.available == true && !isa(d,PSY.StaticLoad))] : devices = dev_set[1]

    p_cl = activepowervariables(m, devices, sys.time_periods);

    varnetinjectiterate!(netinjection.var_active, p_cl, sys.time_periods, devices)

    activepower(m, devices, category_formulation, system_formulation, sys.time_periods)

    cost = variablecost(m, devices, category_formulation, system_formulation)

    add_to_cost!(m, cost)

end


function constructdevice!(m::JuMP.AbstractModel, netinjection::BalanceNamedTuple, category::Type{L}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {L <: PSY.ElectricLoad, D <: FullControllablePowerLoad, S <: AbstractACPowerModel}

    dev_set = [d for d in sys.loads if (d.available == true && !isa(d,PSY.StaticLoad))]

    constructdevice!(m, netinjection, category, category_formulation, PM.AbstractPowerFormulation, sys; devices = dev_set)

    q_cl = reactivepowervariables(m, dev_set, sys.time_periods);

    varnetinjectiterate!(netinjection.var_reactive, q_cl, sys.time_periods, dev_set)

    reactivepower(m, dev_set, category_formulation, system_formulation, sys.time_periods)

end
