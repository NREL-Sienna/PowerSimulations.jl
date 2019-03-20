### Thermal Generation Formulations

abstract type AbstractThermalFormulation <: AbstractDeviceFormulation end

abstract type AbstractThermalDispatchForm <: AbstractThermalFormulation end

struct ThermalUnitCommitment <: AbstractThermalFormulation end

struct ThermalDispatch <: AbstractThermalDispatchForm end

struct ThermalRampLimited <: AbstractThermalDispatchForm end

struct ThermalDispatchNoMin <: AbstractThermalDispatchForm end

# Variables for Thermal Generation

"""
This function add the variables for power generation output to the model
"""
function activepower_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, devices, time_range, :Pth, false, :var_active)

    return

end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, devices, time_range, :Qth, false, :var_reactive)

    return

end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, devices, time_range, :on_th, true)
    add_variable(ps_m, devices, time_range, :start_th, true)
    add_variable(ps_m, devices, time_range, :stop_th, true)

    return

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{T,1},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      D <: AbstractThermalDispatchForm,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_range(ps_m, range_data, time_range, :thermal_active_range, :Pth)

    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{T,1},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      D <: AbstractThermalFormulation,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data, time_range, :thermal_active_range, :Pth, :on_th)

    return

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{T,1},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalDispatchForm,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_range(ps_m, range_data , time_range, :thermal_reactive_range, :Qth)

    return

end



"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{T,1},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalFormulation,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data , time_range, :thermal_reactive_range, :Qth, :on_th)

    return

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{T,1},
                                 device_formulation::Type{PSI.ThermalDispatchNoMin},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.activepowerlimits.max)) for g in devices]

    device_range(ps_m, range_data, time_range, :thermal_active_range, :Pth)

    return

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{T,1},
                                   device_formulation::Type{PSI.ThermalDispatchNoMin},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.reactivepowerlimits.max)) for g in devices]

    device_range(ps_m, range_data , time_range, :thermal_reactive_range, :Qth)

    return

end


### Constraints for Thermal Generation without commitment variables ####

"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    named_initial_conditions = [(d.name, initial_conditions[ix]) for (ix, d) in enumerate(devices)]

    device_commitment(ps_m, named_initial_conditions, time_range, :commitment_th, (:start_th, :stop_th, :on_th))

    return

end


# ramping constraints

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    p_rate_data = [(g.name, g.tech.ramplimits, g.tech.activepowerlimits) for g in devices if !isa(g.tech.ramplimits, Nothing)]

    if !isempty(p_rate_data)

        device_mixedinteger_rateofchange(ps_m, p_rate_data, initial_conditions, time_range, :ramp_thermal, (:Pth, :start_th, :stop_th))
        @info "Thermal Ramp Model doesn't include Reactive Power Ramp Constraints"
        #TODO: ramping for reactive power

    else

        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"

    end

    return

end


function ramp_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    p_rate_data = [(g.name, g.tech.ramplimits) for g in devices if !isa(g.tech.ramplimits, Nothing)]

    if !isempty(p_rate_data)

        device_linear_rateofchange(ps_m, p_rate_data, initial_conditions, time_range, :ramp_thermal, :Pth)
        #TODO: ramping for reactive power
        @info "Thermal Ramp Model doesn't include Reactive Power Ramp Constraints"

    else

        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"

    end

    return

end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractActivePowerFormulation}

    p_rate_data = [(g.name, g.tech.ramplimits, g.tech.activepowerlimits) for g in devices if !isa(g.tech.ramplimits, Nothing)]

    if !isempty(p_rate_data)

        device_mixedinteger_rateofchange(ps_m, p_rate_data, initial_conditions, time_range, :ramp_thermal, (:Pth, :start_th, :stop_th))

    else

        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"

    end

    return

end


function ramp_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractActivePowerFormulation}

    p_rate_data = [(g.name, g.tech.ramplimits) for g in devices if !isa(g.tech.ramplimits, Nothing)]

    if !isempty(p_rate_data)

        device_linear_rateofchange(ps_m, p_rate_data, initial_conditions, time_range, :ramp_thermal, :Pth)

    else

        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"

    end

    return

end


# time constraints

function time_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,2}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    duration_data = [(g.name, g.tech.timelimits) for g in devices if !isa(g.tech.timelimits, Nothing)]

    if !isempty(duration_data)

        device_duration_retrospective(ps_m, duration_data, initial_conditions, time_range, :time, (:on_th, :start_th, :stop_th))

    else

        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"

    end

    return

end


# thermal generation cost

function cost_function(ps_m::CanonicalModel,
                       devices::Array{T,1},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalDispatchForm,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices, :Pth, :variablecost)

    return

end


function cost_function(ps_m::CanonicalModel,
                       devices::Array{T,1},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalFormulation,
                                                           S <: PM.AbstractPowerFormulation}

    #Variable Cost component
    add_to_cost(ps_m, devices, :Pth, :variablecost)

    #Commitment Cost Components
     "Commitment Cost"
    add_to_cost(ps_m, devices, :start_th, :startupcost)
    add_to_cost(ps_m, devices, :stop_th, :shutdncost)
    add_to_cost(ps_m, devices, :on_th, :fixedcost)

    return

end
