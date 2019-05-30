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
                               time_steps::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    var_name = Symbol("Pth_$(T)")
    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, (d.name for d in devices), time_steps)

    for t in time_steps, d in devices
        ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                base_name="{$(var_name)}_{$(d.name),$(t)}",
                                                upper_bound = d.tech.activepowerlimits.max,
                                                lower_bound = d.tech.activepowerlimits.min,
                                                start = d.tech.activepower)
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            d.bus.number,
                            t,
                            ps_m.variables[var_name][d.name,t])
    end

    return

end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{T},
                                 time_steps::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    var_name = Symbol("Qth_$(T)")
    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, (d.name for d in devices), time_steps)

     for t in time_steps, d in devices
        ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                base_name="{$(var_name)}_{$(d.name),$(t)}",
                                                upper_bound = d.tech.reactivepowerlimits.max,
                                                lower_bound = d.tech.reactivepowerlimits.min,
                                                start = d.tech.reactivepower)
        _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                            d.bus.number,
                            t,
                            ps_m.variables[var_name][d.name,t])
    end

    return

end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables(ps_m::CanonicalModel,
                              devices::PSY.FlattenedVectorsIterator{T},
                              time_steps::UnitRange{Int64}) where {T <: PSY.ThermalGen}

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
                                 time_steps::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      D <: AbstractThermalDispatchForm,
                                                                      S <: PM.AbstractPowerFormulation}
    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_range(ps_m,
                 range_data,
                 time_range,
                 Symbol("thermal_active_range_$(T)"),
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
                                 time_steps::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      D <: AbstractThermalFormulation,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m,
                               range_data,
                               time_range,
                               Symbol("thermal_active_range_$(T)"),
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
                                   time_steps::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalDispatchForm,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_range(ps_m,
                 range_data ,
                 time_range,
                 Symbol("thermal_reactive_range_$(T)"),
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
                                   time_steps::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalFormulation,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m,
                               range_data,
                               time_range,
                               Symbol("thermal_reactive_range_$(T)"),
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
                                 time_steps::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.activepowerlimits.max)) for g in devices]

    device_range(ps_m,
                 range_data,
                 time_range,
                 Symbol("thermal_active_range_$(T)"),
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
                                   time_steps::UnitRange{Int64}) where {T <: PSY.ThermalGen,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.reactivepowerlimits.max)) for g in devices]

    device_range(ps_m,
                 range_data,
                 time_range,
                 Symbol("thermal_reactive_range_$(T)"),
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
                                time_steps::UnitRange{Int64},
                                parameters::Bool) where {T <: PSY.ThermalGen,
                                                                     D <: AbstractThermalFormulation,
                                                                     S <: PM.AbstractPowerFormulation}

    key = Symbol("status_$(T)")
    if !(key in keys(ps_m.initial_conditions))
        @warn("Initial status conditions not provided. This can lead to unwanted results")
        status_init(ps_m, devices, parameters)
    end

    device_commitment(ps_m,
                      ps_m.initial_conditions[:thermal_status],
                      time_range,
                      Symbol("commitment_$(T)"),
                      (Symbol("STARTth_$(T)"),
                       Symbol("STOPth_$(T)"),
                       Symbol("ONth_$(T)"))
                      )

    return

end


# ramping constraints

function _get_data_for_rocc(devices::PSY.FlattenedVectorsIterator{T},
                            resolution::Dates.Period) where {T <: PSY.ThermalGen}

    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        minutes_per_period = Dates.value(Dates.Second(resolution))/60
    end

    lenght_devices = length(devices)
    set_name = Vector{String}(undef, lenght_devices)
    ramp_params = Vector{UpDown}(undef, lenght_devices)
    minmax_params = Vector{MinMax}(undef, lenght_devices)

    idx = 0
    for g in devices
        if !isnothing(g.tech.ramplimits)
            max = g.tech.activepowerlimits.max
            min = g.tech.activepowerlimits.min
            if g.tech.ramplimits.up*g.tech.rating >= (max - min)/minutes_per_period
                @info "Generator $(g.name) has a nonbinding ramp up limit. Constraint Skipped"
                continue
            end
            if g.tech.ramplimits.down*g.tech.rating >= (max - min)/minutes_per_period
                @info "Generator $(g.name) has a nonbinding ramp down limit. Constraint Skipped"
                continue
            end
            idx += 1
            set_name[idx] = g.name
            ramp_params[idx] = (up = g.tech.ramplimits.up*minutes_per_period, down = g.tech.ramplimits.down*minutes_per_period)
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
                          time_steps::UnitRange{Int64},
                          resolution::Dates.Period,
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalFormulation,
                                                               S <: PM.AbstractPowerFormulation}

    data = _get_data_for_rocc(devices, resolution)

    if !isempty(data[2])
        key = Symbol("output_$(T)")
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, data[1], parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[:thermal_output])
        # Here goes the reactive power ramp limits
        device_mixedinteger_rateofchange(ps_m,
                                        data,
                                        ps_m.initial_conditions[:thermal_output],
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
                          time_steps::UnitRange{Int64},
                          resolution::Dates.Period,
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalDispatchForm,
                                                               S <: PM.AbstractPowerFormulation}

    data = _get_data_for_rocc(devices, resolution)

    if !isempty(data[2])
        key = Symbol("output_$(T)")
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, data[1], parameters)
        end

        @assert length(data[2]) == length(ps_m.initial_conditions[key])

        # Here goes the reactive power ramp limits
        device_linear_rateofchange(ps_m,
                                   (data[1], data[2]),
                                   ps_m.initial_conditions[:thermal_output], time_range,
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

    lenght_devices = length(devices)
    set_name = Vector{String}(undef, lenght_devices)
    time_params = Vector{UpDown}(undef, lenght_devices)
    initial_conditions_on = Vector{InitialCondition}(undef, lenght_devices)
    initial_conditions_off = Vector{InitialCondition}(undef, lenght_devices)

    idx = 0
    for g in devices
        if !isnothing(g.tech.timelimits)
            set_name[i] = g.name
            time_params[i] = g.tech.timelimits
            (ix_n, initial_conditions_on[i]) = [(ix,ini) for (ix,ini) in enumerate(ini_cond_on) if ini.device == g][1]
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
                          time_steps::UnitRange{Int64},
                          resolution::Dates.Period,
                          parameters::Bool) where {T <: PSY.ThermalGen,
                                                               D <: AbstractThermalFormulation,
                                                               S <: PM.AbstractPowerFormulation}

     # Get the data from the Array of Generators
     key_on = parameters ? Symbol("duration_indicator_on_$(T)") :   Symbol("duration_on_$(T)")
     key_off = parameters ? Symbol("duration_indicator_off_$(T)") : Symbol("duration_on_$(T)")

    if !(key_on in keys(ps_m.initial_conditions))
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
                       devices::PSY.FlattenedVectorsIterator{T},
                       device_formulation::Type{D},
                       system_formulation::Type{S},
                       resolution::Dates.Period) where {T <: PSY.ThermalGen,
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
                       system_formulation::Type{S},
                       resolution::Dates.Period) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalFormulation,
                                                           S <: PM.AbstractPowerFormulation}

    #Variable Cost component
    add_to_cost(ps_m,
                devices,
                Symbol("Pth_$(T)"),
                :variablecost)

    #Commitment Cost Components
    add_to_cost(ps_m, devices, resolution, Symbol("STARTth_$(T)"), :startupcost)
    add_to_cost(ps_m, devices, resolution, Symbol("STOPth_$(T)"), :shutdncost)
    add_to_cost(ps_m, devices, resolution, Symbol("ONth_$(T)"), :fixedcost)

    return

end
