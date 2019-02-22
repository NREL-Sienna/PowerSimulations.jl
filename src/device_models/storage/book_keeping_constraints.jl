function energy_balance_constraint(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    named_initial_conditions = [(d.name, initial_conditions[ix]) for (ix, d) in enumerate(devices)]

    p_eff_data = [(d.name, d.energy) for d in devices if !isa(d.energy, Nothing)]

    if !isempty(p_rate_data)

        energy_balance(ps_m,time_range,named_initial_conditions,p_eff_data, "energy_balance",("Psout","Psin","Est"))

    else
        @warn "Data doesn't contain Storage efficiency , consider adjusting your formulation"
    end

end