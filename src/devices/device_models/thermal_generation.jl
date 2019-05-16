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
                               devices::PSY.FlattenedVectorsIterator{T},
                               time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Pth_$(T)"), 
                 false, 
                 :nodal_balance_active)

    return

end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{T},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Qth_$(T)"), 
                 false, 
                 :nodal_balance_reactive)

    return

end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables(ps_m::CanonicalModel,
                              devices::PSY.FlattenedVectorsIterator{T},
                              time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, 
                devices, 
                time_range, 
                Symbol("ONth_$(T)"), 
                true)
    add_variable(ps_m, 
                devices, 
                time_range, 
                Symbol("STARTth_$(T)"), 
                true)
    add_variable(ps_m, 
                devices, 
                time_range, 
                Symbol("STOPth_$(T)"), 
                true)

    return

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      D <: AbstractThermalDispatchForm,
                                                                      S <: PM.AbstractPowerFormulation}
    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_range(ps_m, 
                 range_data, 
                 time_range, 
                 Symbol("active_range_$(T)"), 
                 Symbol("Pth_$(T)")
                 )

    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      D <: AbstractThermalFormulation,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, 
                               range_data, 
                               time_range, 
                               Symbol("active_range_$(T)"), 
                               Symbol("Pth_$(T)"), 
                               Symbol("ONth_$(T)"))

    return

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::PSY.FlattenedVectorsIterator{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalDispatchForm,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_range(ps_m, 
                 range_data , 
                 time_range, 
                 Symbol("reactive_range_$(T)"), 
                 Symbol("Qth_$(T)"))

    return

end



"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::PSY.FlattenedVectorsIterator{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalFormulation,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, 
                               range_data, 
                               time_range, 
                               Symbol("reactive_range_$(T)"), 
                               Symbol("Qth_$(T)"), 
                               Symbol("ONth_$(T)"))

    return

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{T},
                                 device_formulation::Type{ThermalDispatchNoMin},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.activepowerlimits.max)) for g in devices]

    device_range(ps_m, 
                 range_data, 
                 time_range, 
                 Symbol("active_range_$(T)"), 
                 Symbol("Pth_$(T)"))

    return

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::PSY.FlattenedVectorsIterator{T},
                                   device_formulation::Type{ThermalDispatchNoMin},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.reactivepowerlimits.max)) for g in devices]

    device_range(ps_m, 
                 range_data, 
                 time_range, 
                 Symbol("reactive_range_$(T)"),  
                 Symbol("Qth_$(T)"))

    return

end


### Constraints for Thermal Generation without commitment variables ####

"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{T},
                                device_formulation::Type{D},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64},
                                parameters::Bool) where {T <: PSY.ThermalGen,
                                                                     D <: AbstractThermalFormulation,
                                                                     S <: PM.AbstractPowerFormulation}

    key = Symbol("status_$(T)") 
    if !(key in keys(ps_m.initial_conditions))
        @warn("Initial status conditions not provided. This can lead to unwanted results")
        status_init(ps_m, devices, parameters)
    end

    device_commitment(ps_m,
                      ps_m.initial_conditions[key],
                      time_range, 
                      Symbol("commitment_$(T)"), 
                      (Symbol("STARTth_$(T)"), 
                       Symbol("STOPth_$(T)"), 
                       Symbol("ONth_$(T)"))
                      )

    return

end


# ramping constraints

function _get_data_for_rocc(devices::PSY.FlattenedVectorsIterator{T}) where {T <: PSY.ThermalGen}

    lenght_devices = length(devices)
    set_name = Vector{String}(undef, lenght_devices)
    ramp_params = Vector{UpDown}(undef, lenght_devices)
    minmax_params = Vector{MinMax}(undef, lenght_devices)

    idx = 0
    for g in devices
        if !isnothing(g.tech.ramplimits)
            idx += 1
            set_name[idx] = g.name
            ramp_params[idx] = g.tech.ramplimits
            minmax_params[idx] = g.tech.activepowerlimits
        end
    end

    if idx < lenght_devices 
        deleteat!(set_name, idx+1:lenght_devices)
        deleteat!(ramp_params, idx+1:lenght_devices)
        deleteat!(minmax_params, idx+1:lenght_devices)
    end

    return set_name, ramp_params, minmax_params

end

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints(ps_m::CanonicalModel,
                          devices::PSY.FlattenedVectorsIterator{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalFormulation,
                                                               S <: PM.AbstractPowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2])
        key = Symbol("output_$(T)") 
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[key])
        # Here goes the reactive power ramp limits
        device_mixedinteger_rateofchange(ps_m,
                                        data,
                                        ps_m.initial_conditions[key],
                                        time_range,
                                        Symbol("ramp_$(T)"),  
                                        (Symbol("Pth_$(T)"),
                                         Symbol("STARTth_$(T)"), 
                                         Symbol("STOPth_$(T)"))
                                        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


function ramp_constraints(ps_m::CanonicalModel,
                          devices::PSY.FlattenedVectorsIterator{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalDispatchForm,
                                                               S <: PM.AbstractPowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2])
        key = Symbol("output_$(T)") 
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[key])

        # Here goes the reactive power ramp limits
        device_linear_rateofchange(ps_m,
                                   (data[1], data[2]),
                                   ps_m.initial_conditions[key], time_range,
                                   Symbol("ramp_$(T)"), 
                                   Symbol("Pth_$(T)"))
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints(ps_m::CanonicalModel,
                          devices::PSY.FlattenedVectorsIterator{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalFormulation,
                                                               S <: PM.AbstractActivePowerFormulation}
                                                            
    data = _get_data_for_rocc(devices)

    if !isempty(data[2])
        key = Symbol("output_$(T)") 
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[key])

        device_mixedinteger_rateofchange(ps_m,
                                        data,
                                        ps_m.initial_conditions[key],
                                        time_range,
                                        Symbol("ramp_$(T)"), 
                                        (Symbol("Pth_$(T)"), 
                                        Symbol("STARTth_$(T)"), 
                                        Symbol("STOPth_$(T)"))
                                        )

    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


function ramp_constraints(ps_m::CanonicalModel,
                          devices::PSY.FlattenedVectorsIterator{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalDispatchForm,
                                                               S <: PM.AbstractActivePowerFormulation}

    data = _get_data_for_rocc(devices)

    if !isempty(data[2])
        key = Symbol("output_$(T)") 
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[key])

        device_linear_rateofchange(ps_m,
                                    (data[1], data[2]),
                                    ps_m.initial_conditions[key], 
                                    time_range,
                                    Symbol("ramp_$(T)"), 
                                    Symbol("Pth_$(T)"))
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


# time constraints

function _get_data_for_tdc(devices::PSY.FlattenedVectorsIterator{T}, 
                           ini_cond_on::Vector{InitialCondition},  
                           ini_cond_off::Vector{InitialCondition}) where {T <: PSY.ThermalGen}

    lenght_devices = length(devices)
    set_name = Vector{String}(undef, lenght_devices)
    time_params = Vector{UpDown}(undef, lenght_devices)
    initial_conditions_on = Vector{InitialCondition}(undef, lenght_devices)
    initial_conditions_off = Vector{InitialCondition}(undef, lenght_devices)

    idx = 0
    for g in devices
        if !isnothing(g.tech.timelimits)
            idx += 1
            set_name[idx] = g.name
            time_params[idx] = g.tech.timelimits            
            (ix_n, initial_conditions_on[idx]) = [(ix,ini) for (ix,ini) in enumerate(ini_cond_on) if ini.device == g][1]
            deleteat!(ini_cond_on, ix_n)
            (ix_f, initial_conditions_off[idx]) = [(ix,ini) for (ix,ini) in enumerate(ini_cond_off) if ini.device == g][1]
            deleteat!(ini_cond_off, ix_f)
        end
    end

    if idx < lenght_devices 
        deleteat!(set_name, idx+1:lenght_devices)
        deleteat!(time_params, idx+1:lenght_devices)
        deleteat!(initial_conditions_on, idx+1:lenght_devices)
        deleteat!(initial_conditions_off, idx+1:lenght_devices)
    end

    return set_name, time_params, initial_conditions_on, initial_conditions_off
end

function time_constraints(ps_m::CanonicalModel,
                          devices::PSY.FlattenedVectorsIterator{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalFormulation,
                                                               S <: PM.AbstractPowerFormulation}

     # Get the data from the Array of Generators                  
     key_on = parameters ? Symbol("duration_indicator_on_$(T)") :   Symbol("duration_on_$(T)")
     key_off = parameters ? Symbol("duration_indicator_off_$(T)") : Symbol("duration_off_$(T)")                                        

    if !(key_on in keys(ps_m.initial_conditions))
        @warn("Initial Conditions for Time Up/Down constraints not provided. This can lead to unwanted results")
        time_limits = duration_init(ps_m, devices, parameters)   
    end
    
    if !time_limits
    
     duration_data = _get_data_for_tdc(devices,
                                      ps_m.initial_conditions[key_on],
                                      ps_m.initial_conditions[key_off])                                                                 
   
       if parameters          
            device_duration_indicator(ps_m, 
                                      duration_data[1],
                                      duration_data[2],
                                      duration_data[3],
                                      duration_data[4],
                                      time_range, 
                                      Symbol("duration_$(T)"), 
                                      (Symbol("ONth_$(T)"),
                                       Symbol("STARTth_$(T)"), 
                                       Symbol("STOPth_$(T)"))
                                      )
        else
            device_duration_retrospective(ps_m,
                                        duration_data[1],
                                        duration_data[2],
                                        duration_data[3],
                                        duration_data[4],
                                        time_range, 
                                        Symbol("duration_$(T)"),
                                        (Symbol("ONth_$(T)"),
                                        Symbol("STARTth_$(T)"), 
                                        Symbol("STOPth_$(T)"))
                                        )
        end
    else
        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"
    end

    return

end


# thermal generation cost

function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenedVectorsIterator{T},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalDispatchForm,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, 
                devices, 
                Symbol("Pth_$(T)"), 
                :variablecost)

    return

end


function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenedVectorsIterator{T},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalFormulation,
                                                           S <: PM.AbstractPowerFormulation}

    #Variable Cost component
    add_to_cost(ps_m, 
                devices, 
                Symbol("Pth_$(T)"), 
                :variablecost)

    #Commitment Cost Components
    add_to_cost(ps_m, devices, Symbol("STARTth_$(T)"), :startupcost)
    add_to_cost(ps_m, devices, Symbol("STOPth_$(T)"), :shutdncost)
    add_to_cost(ps_m, devices, Symbol("ONth_$(T)"), :fixedcost)

    return

end
