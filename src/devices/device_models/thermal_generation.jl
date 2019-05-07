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
                               devices::Vector{T},
                               time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m,
                 devices,
                 time_range,
                 Symbol("Pth_$(eltype(devices))"),
                 false,
                 :var_active)

    return

end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables(ps_m::CanonicalModel,
                                 devices::Vector{T},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m,
                 devices,
                 time_range,
                 Symbol("Qth_$(eltype(devices))"),
                 false,
                 :var_reactive)

    return

end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables(ps_m::CanonicalModel,
                              devices::Vector{T},
                              time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m,
                devices,
                time_range,
                Symbol("ONth_$(eltype(devices))"),
                true)
    add_variable(ps_m,
                devices,
                time_range,
                Symbol("STARTth_$(eltype(devices))"),
                true)
    add_variable(ps_m,
                devices,
                time_range,
                Symbol("STOPth_$(eltype(devices))"),
                true)

    return

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      D <: AbstractThermalDispatchForm,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_range(ps_m,
                 range_data,
                 time_range,
                 :thermal_active_range,
                 Symbol("Pth_$(eltype(devices))")
                 )

    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      D <: AbstractThermalFormulation,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m,
                               range_data,
                               time_range,
                               :thermal_active_range,
                               Symbol("Pth_$(eltype(devices))"),
                               Symbol("ONth_$(eltype(devices))"))

    return

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Vector{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalDispatchForm,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_range(ps_m,
                 range_data ,
                 time_range,
                 :thermal_reactive_range,
                 Symbol("Qth_$(eltype(devices))"))

    return

end



"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Vector{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalFormulation,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m,
                               range_data,
                               time_range,
                               :thermal_reactive_range,
                               Symbol("Qth_$(eltype(devices))"),
                               Symbol("ONth_$(eltype(devices))"))

    return

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{T},
                                 device_formulation::Type{PSI.ThermalDispatchNoMin},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.activepowerlimits.max)) for g in devices]

    device_range(ps_m,
                 range_data,
                 time_range,
                 :thermal_active_range,
                 Symbol("Pth_$(eltype(devices))"))

    return

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Vector{T},
                                   device_formulation::Type{PSI.ThermalDispatchNoMin},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.reactivepowerlimits.max)) for g in devices]

    device_range(ps_m,
                 range_data,
                 time_range,
                 :thermal_reactive_range,
                 Symbol("Qth_$(eltype(devices))"))

    return

end


### Constraints for Thermal Generation without commitment variables ####

"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints(ps_m::CanonicalModel,
                                devices::Vector{T},
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
                      time_range,
                      :commitment_th,
                      (Symbol("STARTth_$(eltype(devices))"),
                       Symbol("STOPth_$(eltype(devices))"),
                       Symbol("ONth_$(eltype(devices))"))
                      )

    return

end


# ramping constraints

function _get_data_for_rocc(devices::Vector{T}) where {T <: PSY.ThermalGen}

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
            y = iterate(idx, state)
            y === nothing && (i += 1; break)
            i, state = y
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
                          devices::Vector{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalFormulation,
                                                               S <: PM.AbstractPowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2])
        if !(:thermal_output in keys(ps_m.initial_conditions))
            @info("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[:thermal_output])
        # Here goes the reactive power ramp limits
        device_mixedinteger_rateofchange(ps_m,
                                        data,
                                        ps_m.initial_conditions[:thermal_output],
                                        time_range,
                                        :ramp_thermal,
                                        (Symbol("Pth_$(eltype(devices))"),
                                         Symbol("STARTth_$(eltype(devices))"),
                                         Symbol("STOPth_$(eltype(devices))"))
                                        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


function ramp_constraints(ps_m::CanonicalModel,
                          devices::Vector{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalDispatchForm,
                                                               S <: PM.AbstractPowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2])
        if !(:thermal_output in keys(ps_m.initial_conditions))
            @info("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end
        # Here goes the reactive power ramp limits
        device_linear_rateofchange(ps_m,
                                   (data[1], data[2]),
                                   ps_m.initial_conditions[:thermal_output], time_range,
                                   :ramp_thermal,
                                   Symbol("Pth_$(eltype(devices))"))
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints(ps_m::CanonicalModel,
                          devices::Vector{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalFormulation,
                                                               S <: PM.AbstractActivePowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2])
        if !(:thermal_output in keys(ps_m.initial_conditions))
            @info("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[:thermal_output])

        device_mixedinteger_rateofchange(ps_m,
                                        data,
                                        ps_m.initial_conditions[:thermal_output],
                                        time_range,
                                        :ramp_thermal,
                                        (Symbol("Pth_$(eltype(devices))"),
                                        Symbol("STARTth_$(eltype(devices))"),
                                        Symbol("STOPth_$(eltype(devices))"))
                                        )

    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


function ramp_constraints(ps_m::CanonicalModel,
                          devices::Vector{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalDispatchForm,
                                                               S <: PM.AbstractActivePowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2])
        if !(:thermal_output in keys(ps_m.initial_conditions))
            @info("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end
        device_linear_rateofchange(ps_m,
                                    (data[1], data[2]),
                                    ps_m.initial_conditions[:thermal_output], time_range,
                                    :ramp_thermal,
                                    Symbol("Pth_$(eltype(devices))"))
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


# time constraints

function _get_data_for_tdc(devices::Vector{T},
                           ini_cond_on::Vector{InitialCondition},
                           ini_cond_off::Vector{InitialCondition}) where {T <: PSY.ThermalGen}

    set_name = Vector{String}(undef, length(devices))
    time_params = Vector{UpDown}(undef, length(devices))
    initial_conditions_on = Vector{InitialCondition}(undef, length(devices))
    initial_conditions_off = Vector{InitialCondition}(undef, length(devices))

    idx = eachindex(devices)
    i, state = iterate(idx)
    for g in devices
        if !isnothing(g.tech.timelimits)
            set_name[i] = g.name
            time_params[i] = g.tech.timelimits
            (ix_n, initial_conditions_on[i]) = [(ix,ini) for (ix,ini) in enumerate(ini_cond_on) if ini.device == g][1]
            deleteat!(ini_cond_on, ix_n)
            (ix_f, initial_conditions_off[i]) = [(ix,ini) for (ix,ini) in enumerate(ini_cond_off) if ini.device == g][1]
            deleteat!(ini_cond_off, ix_f)
            y = iterate(idx, state)
            y === nothing && (i += 1; break)
            i, state = y
        end
    end

    deleteat!(set_name, i:last(idx))
    deleteat!(time_params, i:last(idx))
    deleteat!(initial_conditions_on, i:last(idx))
    deleteat!(initial_conditions_off, i:last(idx))

    return set_name, time_params, initial_conditions_on, initial_conditions_off
end

function time_constraints(ps_m::CanonicalModel,
                          devices::Vector{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalFormulation,
                                                               S <: PM.AbstractPowerFormulation}


    if !(:thermal_duration_on in keys(ps_m.initial_conditions))
        @info("Initial Conditions for Time Up/Down constraints not provided. This can lead to unwanted results")
        duration_init(ps_m, devices, parameters)
    end

    # Get the data from the Array of Generators
    key_on = parameters ? :duration_indicator_status_on :   :thermal_duration_on
    key_off = parameters ? :duration_indicator_status_off : :thermal_duration_off
    duration_data = _get_data_for_tdc(devices,
                                      ps_m.initial_conditions[key_on],
                                      ps_m.initial_conditions[key_off])

    if !isempty(duration_data[2])
       if parameters
            device_duration_indicator(ps_m,
                                      duration_data[1],
                                      duration_data[2],
                                      duration_data[3],
                                      duration_data[4],
                                      time_range, :duration_thermal,
                                      (:on_th, :start_th, :stop_th))
        else
            device_duration_retrospective(ps_m,
                                        duration_data[1],
                                        duration_data[2],
                                        duration_data[3],
                                        duration_data[4],
                                        time_range, :duration_thermal,
                                        (:on_th, :start_th, :stop_th))
        end
        @warn("Currently Min-up/down time limits only work if time resoultion they are defined at matches the simulation's time resoultion")
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
                       devices::Vector{T},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalDispatchForm,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m,
                devices,
                Symbol("Pth_$(eltype(devices))"),
                :variablecost)

    return

end


function cost_function(ps_m::CanonicalModel,
                       devices::Vector{T},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalFormulation,
                                                           S <: PM.AbstractPowerFormulation}

    #Variable Cost component
    add_to_cost(ps_m,
                devices,
                Symbol("Pth_$(eltype(devices))"),
                :variablecost)

    #Commitment Cost Components
    add_to_cost(ps_m, devices, Symbol("STARTth_$(eltype(devices))"), :startupcost)
    add_to_cost(ps_m, devices, Symbol("STOPth_$(eltype(devices))"), :shutdncost)
    add_to_cost(ps_m, devices, Symbol("ONth_$(eltype(devices))"), :fixedcost)

    return

end
