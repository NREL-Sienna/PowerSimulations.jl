########################### Thermal Generation Models ######################################

abstract type AbstractThermalFormulation <: AbstractDeviceFormulation end

abstract type AbstractThermalDispatchForm <: AbstractThermalFormulation end

struct ThermalUnitCommitment <: AbstractThermalFormulation end

struct ThermalDispatch <: AbstractThermalDispatchForm end

struct ThermalRampLimited <: AbstractThermalDispatchForm end

struct ThermalDispatchNoMin <: AbstractThermalDispatchForm end

########################### Active Dispatch Variables ######################################

"""
This function add the variables for power generation output to the model
"""
function activepower_variables!(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{T}) where {T <: PSY.ThermalGen}

    time_steps = model_time_steps(ps_m)
    var_name = Symbol("P_$(T)")
    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel,
                                              (d.name for d in devices),
                                              time_steps)

    for t in time_steps, d in devices
        ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                base_name="{$(var_name)}_{$(d.name),$(t)}",
                                                #upper_bound = d.tech.activepowerlimits.max,
                                                #lower_bound = 0.0,
                                                #start = d.tech.activepower
                                                )
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
function reactivepower_variables!(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{T}) where {T <: PSY.ThermalGen}

    time_steps = model_time_steps(ps_m)
    var_name = Symbol("Q_$(T)")
    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel,
                                              (d.name for d in devices),
                                              time_steps)

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
function commitment_variables!(ps_m::CanonicalModel,
                              devices::PSY.FlattenedVectorsIterator{T}) where {T <: PSY.ThermalGen}

    time_steps = model_time_steps(ps_m)
    var_names = [Symbol("ON_$(T)"), Symbol("START_$(T)"), Symbol("STOP_$(T)")]

    for v in var_names
        add_variable(ps_m, devices, v, true)
    end

    return

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints!(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                                     D <: AbstractThermalDispatchForm,
                                                                     S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_range(ps_m,
                range_data,
                Symbol("active_range_$(T)"),
                Symbol("P_$(T)")
                )
    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function activepower_constraints!(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                                      D <: AbstractThermalFormulation,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m,
                               range_data,
                               Symbol("active_range_$(T)"),
                               Symbol("P_$(T)"),
                               Symbol("ON_$(T)"))

    return

end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints!(ps_m::CanonicalModel,
                                   devices::PSY.FlattenedVectorsIterator{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalDispatchForm,
                                                                        S <: PM.AbstractPowerFormulation}
    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_range(ps_m,
                 range_data ,
                 Symbol("reactive_range_$(T)"),
                 Symbol("Q_$(T)"))

    return

end

"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function reactivepower_constraints!(ps_m::CanonicalModel,
                                   devices::PSY.FlattenedVectorsIterator{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                                        D <: AbstractThermalFormulation,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m,
                               range_data,
                               Symbol("reactive_range_$(T)"),
                               Symbol("Q_$(T)"),
                               Symbol("ON_$(T)"))

    return

end

"""
This function adds the active power limits of generators when there are
    no CommitmentVariables
"""
function activepower_constraints!(ps_m::CanonicalModel,
                                  devices::PSY.FlattenedVectorsIterator{T},
                                  device_formulation::Type{ThermalDispatchNoMin},
                                  system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                                     S <: PM.AbstractPowerFormulation}
    range_data = [(g.name, (min = 0.0, max=g.tech.activepowerlimits.max)) for g in devices]

    device_range(ps_m,
                 range_data,
                 Symbol("active_range_$(T)"),
                 Symbol("P_$(T)"))

    return

end

"""
This function adds the reactive  power limits of generators when there are
    CommitmentVariables
"""
function reactivepower_constraints!(ps_m::CanonicalModel,
                                   devices::PSY.FlattenedVectorsIterator{T},
                                   device_formulation::Type{ThermalDispatchNoMin},
                                   system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.reactivepowerlimits.max)) for g in devices]

    device_range(ps_m,
                 range_data,
                 Symbol("reactive_range_$(T)"),
                 Symbol("Q_$(T)"))

    return

end

### Constraints for Thermal Generation without commitment variables ####
"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints!(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                                     D <: AbstractThermalFormulation,
                                                                     S <: PM.AbstractPowerFormulation}

    key = Symbol("status_$(T)")

    if !(key in keys(ps_m.initial_conditions))
        @warn("Initial status conditions not provided. This can lead to unwanted results")
        status_init(ps_m, devices)
    end

    device_commitment(ps_m,
                      ps_m.initial_conditions[key],
                        Symbol("commitment_$(T)"),
                      (Symbol("START_$(T)"),
                       Symbol("STOP_$(T)"),
                       Symbol("ON_$(T)"))
                      )

    return

end


########################### Ramp/Rate of Change constraints ################################
"""
This function gets the data for the generators
"""
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
        non_binding_up = false
        non_binding_down = false
        if !isnothing(g.tech.ramplimits)
            max = g.tech.activepowerlimits.max
            min = g.tech.activepowerlimits.min
            if g.tech.ramplimits.up*g.tech.rating >= -1*(min - max)/minutes_per_period
                @info "Generator $(g.name) has a nonbinding ramp up limit. Constraint Skipped"
                non_binding_up = true
            end
            if g.tech.ramplimits.down*g.tech.rating >= (max - min)/minutes_per_period
                @info "Generator $(g.name) has a nonbinding ramp down limit. Constraint Skipped"
                non_binding_down = true
            end
            (non_binding_up & non_binding_down) ? continue : idx += 1
            set_name[idx] = g.name
            ramp_params[idx] = (up = g.tech.ramplimits.up*minutes_per_period,
                                down = g.tech.ramplimits.down*minutes_per_period)
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
function ramp_constraints!(ps_m::CanonicalModel,
                           devices::PSY.FlattenedVectorsIterator{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                    D <: AbstractThermalFormulation,
                                                    S <: PM.AbstractPowerFormulation}
    time_steps = model_time_steps(ps_m)
    resolution = model_resolution(ps_m)
    rate_data = _get_data_for_rocc(devices, resolution)

    if !isempty(rate_data[1])
        key = Symbol("output_$(T)")
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, rate_data[1])
        end
        @assert length(rate_data[2]) == length(ps_m.initial_conditions[key])
        # Here goes the reactive power ramp limits
        device_mixedinteger_rateofchange(ps_m,
                                        rate_data,
                                        ps_m.initial_conditions[key],
                                        Symbol("ramp_$(T)"),
                                        (Symbol("P_$(T)"),
                                         Symbol("START_$(T)"),
                                         Symbol("STOP_$(T)"))
                                        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end

function ramp_constraints!(ps_m::CanonicalModel,
                          devices::PSY.FlattenedVectorsIterator{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                   D <: AbstractThermalDispatchForm,
                                                   S <: PM.AbstractPowerFormulation}
    time_steps = model_time_steps(ps_m)
    resolution = model_resolution(ps_m)
    rate_data = _get_data_for_rocc(devices, resolution)

    if !isempty(rate_data[1])
        key = Symbol("output_$(T)")
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, rate_data[1])
        end

        @assert length(rate_data[2]) == length(ps_m.initial_conditions[key])

        # Here goes the reactive power ramp limits
        device_linear_rateofchange(ps_m,
                                   (rate_data[1], rate_data[2]),
                                   ps_m.initial_conditions[key],
                                   Symbol("ramp_$(T)"),
                                   Symbol("P_$(T)"))
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints!(ps_m::CanonicalModel,
                          devices::PSY.FlattenedVectorsIterator{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                   D <: AbstractThermalFormulation,
                                                   S <: PM.AbstractActivePowerFormulation}

    resolution = model_resolution(ps_m)
    rate_data = _get_data_for_rocc(devices, resolution)

    if !isempty(rate_data[1])
        key = Symbol("output_$(T)")
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, rate_data[1])
        end

        @assert length(rate_data[2]) == length(ps_m.initial_conditions[key])

        device_mixedinteger_rateofchange(ps_m,
                                        rate_data,
                                        ps_m.initial_conditions[key],
                                        Symbol("ramp_$(T)"),
                                        (Symbol("P_$(T)"),
                                        Symbol("START_$(T)"),
                                        Symbol("STOP_$(T)"))
                                        )

    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


function ramp_constraints!(ps_m::CanonicalModel,
                           devices::PSY.FlattenedVectorsIterator{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                    D <: AbstractThermalDispatchForm,
                                                    S <: PM.AbstractActivePowerFormulation}

    resolution = model_resolution(ps_m)
    rate_data = _get_data_for_rocc(devices, resolution)

    if !isempty(rate_data[1])
        key = Symbol("output_$(T)")
        if !(key in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(ps_m, devices, rate_data[1])
        end

        @assert length(rate_data[2]) == length(ps_m.initial_conditions[key])

        device_linear_rateofchange(ps_m,
                                    (rate_data[1], rate_data[2]),
                                    ps_m.initial_conditions[key],
                                                       Symbol("ramp_$(T)"),
                                    Symbol("P_$(T)"))
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end


########################### time duration constraints ######################################
"""
If the fraction of hours that a generator has a duration constraint is less than
the fraction of hours that a single time_step represents then it is not binding.
"""
function _get_data_for_tdc(devices::PSY.FlattenedVectorsIterator{T},
                           resolution::Dates.Period) where {T <: PSY.ThermalGen}

    steps_per_hour = 60/Dates.value(Dates.Minute(resolution))
    fraction_of_hour = 1/steps_per_hour
    lenght_devices = length(devices)
    set_name = Vector{String}(undef, lenght_devices)
    time_params = Vector{UpDown}(undef, lenght_devices)

    idx = 0
    for g in devices
        non_binding_up = false
        non_binding_down = false
        if !isnothing(g.tech.timelimits)
            if g.tech.timelimits.up <= fraction_of_hour
                @info "Generator $(g.name) has a nonbinding time limit. Constraint Skipped"
                non_binding_up = true
            end
            if g.tech.timelimits.down <= fraction_of_hour
                @info "Generator $(g.name) has a nonbinding time limit. Constraint Skipped"
                non_binding_down = true
            end
            (non_binding_up & non_binding_down) ? continue : idx += 1
            set_name[idx] = g.name
            up_val = round(g.tech.timelimits.up*steps_per_hour, RoundUp)
            down_val = round(g.tech.timelimits.down*steps_per_hour, RoundUp)
            time_params[idx] = time_params[idx] = (up = up_val, down = down_val)
        end
    end

    if idx < lenght_devices
        deleteat!(set_name, idx+1:lenght_devices)
        deleteat!(time_params, idx+1:lenght_devices)
    end

    return set_name, time_params

end

function time_constraints!(ps_m::CanonicalModel,
                          devices::PSY.FlattenedVectorsIterator{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                   D <: AbstractThermalFormulation,
                                                   S <: PM.AbstractPowerFormulation}

    parameters = model_with_parameters(ps_m)
    resolution = model_resolution(ps_m)
    duration_data = _get_data_for_tdc(devices, resolution)

    if !(isempty(duration_data[1]))

        key_on = parameters ? Symbol("duration_ind_on_$(T)") : Symbol("duration_on_$(T)")
        key_off = parameters ? Symbol("duration_ind_off_$(T)") : Symbol("duration_off_$(T)")
        if !(key_on in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Time Up/Down constraints not provided. This can lead to unwanted results")
            time_limits = duration_init(ps_m, devices, duration_data[1])
        end

        @assert length(duration_data[2]) == length(ps_m.initial_conditions[key_on])
        @assert length(duration_data[2]) == length(ps_m.initial_conditions[key_off])

       if parameters
            device_duration_ind(ps_m,
                                      duration_data[1],
                                      duration_data[2],
                                      ps_m.initial_conditions[key_on],
                                      ps_m.initial_conditions[key_off],
                                    Symbol("duration_$(T)"),
                                      (Symbol("ON_$(T)"),
                                       Symbol("START_$(T)"),
                                       Symbol("STOP_$(T)"))
                                      )
        else
            device_duration_retrospective(ps_m,
                                        duration_data[1],
                                        duration_data[2],
                                        ps_m.initial_conditions[key_on],
                                        ps_m.initial_conditions[key_off],
                                        Symbol("duration_$(T)"),
                                        (Symbol("ON_$(T)"),
                                        Symbol("START_$(T)"),
                                        Symbol("STOP_$(T)"))
                                        )
        end
    else
        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"
    end

    return

end


########################### Cost Function Calls#############################################

function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenedVectorsIterator{T},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalDispatchForm,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m,
                devices,
                Symbol("P_$(T)"),
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
    add_to_cost(ps_m, devices, Symbol("P_$(T)"), :variablecost)

    #Commitment Cost Components
    add_to_cost(ps_m, devices, Symbol("START_$(T)"), :startupcost)
    add_to_cost(ps_m, devices, Symbol("STOP_$(T)"), :shutdncost)
    add_to_cost(ps_m, devices, Symbol("ON_$(T)"), :fixedcost)

    return

end
