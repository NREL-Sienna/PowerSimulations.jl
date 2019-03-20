abstract type AbstractStorageForm <: AbstractDeviceFormulation end

abstract type BookKeepingModel <: AbstractStorageForm end


# storage variables

function activepower_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.Storage}

    add_variable(ps_m, devices, time_range, :Psin, false,:var_active, -1)
    add_variable(ps_m, devices, time_range, :Psout, false, :var_active)

    return

end


function reactivepower_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.Storage}

    add_variable(ps_m, devices, time_range, :Qst, false, :var_reactive)

    return

end


function energystorage_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where T <: PSY.Storage

    add_variable(ps_m, devices, time_range,:Est, false)

    return

end


function storagereservation_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where T <: PSY.Storage

    add_variable(ps_m, devices, time_range, :Sst, true)

    return

end


# output constraints

function activepower_constraints(ps_m::CanonicalModel, devices::Array{St,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {St <: PSY.Storage, D <: AbstractStorageForm, S <: PM.AbstractPowerFormulation}

    range_data_in = [(s.name, s.inputactivepowerlimits) for s in devices]

    range_data_out = [(s.name, s.outputactivepowerlimits) for s in devices]

    device_semicontinuousrange(ps_m, range_data_in, time_range, :storage_inputpower_range, :Psin, :Est)

    reserve_device_semicontinuousrange(ps_m, range_data_in, time_range, :storage_outputpower_range, :Psout, :Sst)

    return

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel, devices::Array{St,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {St <: PSY.Storage, D <: AbstractStorageForm, S <: PM.AbstractPowerFormulation}

    range_data = [(s.name, s.reactivepowerlimits) for s in devices]

    device_range(ps_m, range_data , time_range, :storage_reactive_range, :Qst)

    return

end


# book keeping constraints

function energy_balance_constraint(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.Storage, D <: AbstractStorageForm, S <: PM.AbstractPowerFormulation}

    named_initial_conditions = [(d.name, initial_conditions[ix]) for (ix, d) in enumerate(devices)]

    p_eff_data = [ (d.name,d.energy) for d in devices if !isa(d.energy, Nothing)]

    if !isempty(p_eff_data)

        energy_balance(ps_m,time_range,named_initial_conditions,p_eff_data, :energy_balance,(:Psout,:Psin,:Est))

    else
        @warn "Data doesn't contain Storage efficiency , consider adjusting your formulation"
    end

    return

end
