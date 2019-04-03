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
function activepower_variables(ps_m::CanonicalModel, 
                               devices::Array{T,1}, 
                               time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, devices, time_range, :Pth, false, :var_active)

    return

end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables(ps_m::CanonicalModel, 
                                 devices::Array{T,1}, 
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, devices, time_range, :Qth, false, :var_reactive)

    return

end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables(ps_m::CanonicalModel, 
                              devices::Array{T,1}, 
                              time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

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
function commitment_constraints(ps_m::CanonicalModel, 
                                devices::Array{T,1}, 
                                device_formulation::Type{D}, 
                                system_formulation::Type{S}, 
                                time_range::UnitRange{Int64}, 
                                parameters::Bool) where {T <: PSY.ThermalGen, 
                                                                     D <: AbstractThermalFormulation, 
                                                                     S <: PM.AbstractPowerFormulation}

    
    if !(:thermal_status in keys(ps_m.initial_conditions)) 
        @info("Initial status conditions not provided. This can lead to unwanted results")
        status_init(ps_m, devices, parameters)
    end

    device_commitment(ps_m, 
                      ps_m.initial_conditions[:thermal_status], 
                      time_range, :commitment_th, 
                      (:start_th, :stop_th, :on_th))

    return

end


# ramping constraints

function _get_data_for_rocc(devices::Array{T,1}) where {T <: PSY.ThermalGen}
        
    set_name = Vector{String}(undef, length(devices))
    ramp_params = Vector{UpDown}(undef, length(devices))     
    minmax_params = Vector{MinMax}(undef, length(devices))                                                              

    idx = eachindex(devices)
    i, state = iterate(idx)
    for g in devices
        if !isnothing(g.tech.ramplimits)
            set_name[i] = g.name
            ramp_params[i] = g.tech.ramplimits
            minmax_params[i] = g.tech.activepowerlimits
            i, state = iterate(idx, state)
            state === nothing && (i += 1; break)                                                                   
        end 
    end
    
    deleteat!(set_name, i:last(idx))
    deleteat!(ramp_params, i:last(idx))
    deleteat!(minmax_params, i:last(idx))

    return set_name, ramp_params, minmax_params

end

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints(ps_m::CanonicalModel, 
                          devices::Array{T,1}, 
                          device_formulation::Type{D}, 
                          system_formulation::Type{S}, 
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen, 
                                                               D <: AbstractThermalFormulation, 
                                                               S <: PM.AbstractPowerFormulation}

    data = _get_data_for_rocc(devices)
                                                           
    if !isempty(data[2])
        if !(:thermal_output in keys(ps_m.initial_conditions)) 
            @info("Initial conditions for rate of change not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[:thermal_output])
        # Here goes the reactive power ramp limits
        device_mixedinteger_rateofchange(ps_m, 
                                        data, 
                                        ps_m.initial_conditions[:thermal_output], 
                                        time_range, 
                                        :ramp_thermal, (:Pth, :start_th, :stop_th))    
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


function ramp_constraints(ps_m::CanonicalModel, 
                          devices::Array{T,1}, 
                          device_formulation::Type{D}, 
                          system_formulation::Type{S}, 
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen, 
                                                               D <: AbstractThermalDispatchForm, 
                                                               S <: PM.AbstractPowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2]) 
        if !(:thermal_output in keys(ps_m.initial_conditions)) 
            @info("Initial conditions for rate of change not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end
        # Here goes the reactive power ramp limits
        device_linear_rateofchange(ps_m, 
                                   (data[1], data[2]), 
                                   ps_m.initial_conditions[:thermal_output], time_range, 
                                   :ramp_thermal, :Pth)    
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints(ps_m::CanonicalModel, 
                          devices::Array{T,1}, 
                          device_formulation::Type{D}, 
                          system_formulation::Type{S}, 
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen, 
                                                               D <: AbstractThermalFormulation, 
                                                               S <: PM.AbstractActivePowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2])
        if !(:thermal_output in keys(ps_m.initial_conditions)) 
            @info("Initial conditions for rate of change not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[:thermal_output])

        device_mixedinteger_rateofchange(ps_m, 
                                        data, 
                                        ps_m.initial_conditions[:thermal_output], 
                                        time_range, 
                                        :ramp_thermal, (:Pth, :start_th, :stop_th))
    
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


function ramp_constraints(ps_m::CanonicalModel, 
                          devices::Array{T,1}, 
                          device_formulation::Type{D}, 
                          system_formulation::Type{S}, 
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen, 
                                                               D <: AbstractThermalDispatchForm, 
                                                               S <: PM.AbstractActivePowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2]) 
        if !(:thermal_output in keys(ps_m.initial_conditions)) 
            @info("Initial conditions for rate of change not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end
        device_linear_rateofchange(ps_m, 
                                    (data[1], data[2]), 
                                    ps_m.initial_conditions[:thermal_output], time_range, 
                                    :ramp_thermal, :Pth)
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


# time constraints

function _get_data_for_tdc(devices::Array{T,1}) where {T <: PSY.ThermalGen}
        
    set_name = Vector{String}(undef, length(devices))
    time_params = Vector{UpDown}(undef, length(devices))     

    idx = eachindex(devices)
    i, state = iterate(idx)
    for g in devices
        if !isnothing(g.tech.ramplimits)
            set_name[i] = g.name
            time_params[i] = g.tech.timelimits
            i, state = iterate(idx, state)
            state === nothing && (i += 1; break)                                                                   
        end 
    end
    
    deleteat!(set_name, i:last(idx))
    deleteat!(time_params, i:last(idx))

    return set_name, time_params
end

function time_constraints(ps_m::CanonicalModel, 
                          devices::Array{T,1}, 
                          device_formulation::Type{D}, 
                          system_formulation::Type{S}, 
                          time_range::UnitRange{Int64},
                          parameters::Bool = false) where {T <: PSY.ThermalGen, 
                                                               D <: AbstractThermalFormulation, 
                                                               S <: PM.AbstractPowerFormulation}

    duration_data = _get_data_for_tdc(devices)

    if !isempty(duration_data)
        if !(:thermal_duration_on in keys(ps_m.initial_conditions)) 
            @info("Initial conditions for time up/down not provided. This can lead to unwanted results")
            duration_init(ps_m, devices, parameters)
        end
        device_duration_retrospective(ps_m, 
                                      duration_data, 
                                      ps_m.initial_conditions[:thermal_duration_on],
                                      ps_m.initial_conditions[:thermal_duration_off],
                                      time_range, 
                                      :duration, (:on_th, :start_th, :stop_th))
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
    add_to_cost(ps_m, devices, :start_th, :startupcost)
    add_to_cost(ps_m, devices, :stop_th, :shutdncost)
    add_to_cost(ps_m, devices, :on_th, :fixedcost)

    return

end
