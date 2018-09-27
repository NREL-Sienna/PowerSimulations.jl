function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ElectricLoad}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    dev_set = [a.second for a in args if a.first == :devices]

    isempty(dev_set) ? devices = [d for d in devices if (d.available == true && !isa(d,PowerSystems.StaticLoad))] : devices = dev_set[1]

    p_cl = activepowervariables(m, devices, sys.time_periods);

    varnetinjectiterate!(netinjection.var_active, p_cl, sys.time_periods, devices)

    activepower(m, devices, category_formulation, system_formulation, sys.time_periods)

    cost = variablecost(m, devices, category_formulation, system_formulation)

    add_to_cost!(m, cost)

end


function constructdevice!(m::JuMP.Model, netinjection::BalanceNamedTuple, category::Type{PowerSystems.ElectricLoad}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {D <: AbstractRenewableDispatchForm, S <: AbstractACPowerModel}

    dev_set = [d for d in devices if (d.available == true && !isa(d,PowerSystems.StaticLoad))]

    constructdevice!(m, netinjection, category, category_formulation, PM.AbstractPowerFormulation, sys; devices = dev_set)

    q_cl = reactivepowervariables(m, dev_set, sys.time_periods);

    varnetinjectiterate!(netinjection.var_reactive, q_cl, sys.time_periods, dev_set)

    m = reactivepower(m, dev_set, category_formulation, system_formulation, sys.time_periods)

end
