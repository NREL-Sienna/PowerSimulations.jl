########################### Thermal Generation Models ######################################

abstract type AbstractThermalFormulation<:AbstractDeviceFormulation end

abstract type AbstractThermalDispatchForm<:AbstractThermalFormulation end

struct ThermalUnitCommitment<:AbstractThermalFormulation end

struct ThermalDispatch<:AbstractThermalDispatchForm end

struct ThermalRampLimited<:AbstractThermalDispatchForm end

struct ThermalDispatchNoMin<:AbstractThermalDispatchForm end

########################### Active Dispatch Variables ######################################

"""
This function add the variables for power generation output to the model
"""
function activepower_variables!(ps_m::CanonicalModel,
                           devices::PSY.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}


    add_variable(ps_m,
                 devices,
                 Symbol("P_$(T)"),
                 false,
                 :nodal_balance_active;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0.0,
                 init_value = d -> d.tech.activepower)

    return

end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables!(ps_m::CanonicalModel,
                           devices::PSY.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}

    add_variable(ps_m,
                 devices,
                 Symbol("Q_$(T)"),
                 false,
                 :nodal_balance_reactive;
                 ub_value = d -> d.tech.reactivepowerlimits.max,
                 lb_value = d -> d.tech.reactivepowerlimits.min,
                 init_value = d -> d.tech.reactivepower)

    return

end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables!(ps_m::CanonicalModel,
                           devices::PSY.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}

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
                                 devices::PSY.FlattenIteratorWrapper{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalDispatchForm,
                                                                     S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]

    if model_runs_sequentially(ps_m)
        device_semicontinuousrange_param(ps_m,
                                         range_data,
                                         Symbol("activerange_$(T)"),
                                         Symbol("P_$(T)"),
                                         RefParam{JuMP.VariableRef}(Symbol("ON_$(T)")))
    else
        device_range(ps_m,
                    range_data,
                    Symbol("activerange_$(T)"),
                    Symbol("P_$(T)")
                    )
    end

    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function activepower_constraints!(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                      D<:AbstractThermalFormulation,
                                                                      S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]
    device_semicontinuousrange(ps_m,
                               range_data,
                               Symbol("activerange_$(T)"),
                               Symbol("P_$(T)"),
                               Symbol("ON_$(T)"))

    return

end


"""
This function adds the active power limits of generators when there are
    no CommitmentVariables
"""
function activepower_constraints!(ps_m::CanonicalModel,
                                  devices::PSY.FlattenIteratorWrapper{T},
                                  device_formulation::Type{ThermalDispatchNoMin},
                                  system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), (min = 0.0, max=(PSY.get_tech(g) |> PSY.get_activepowerlimits).max)) for g in devices]

    if model_runs_sequentially(ps_m)
        device_semicontinuousrange_param(ps_m,
                                         range_data,
                                         Symbol("activerange_$(T)"),
                                         Symbol("P_$(T)"),
                                         RefParam{JuMP.VariableRef}(Symbol("ON_$(T)")))
    else
        device_range(ps_m,
                    range_data,
                    Symbol("activerange_$(T)"),
                    Symbol("P_$(T)")
                    )
    end

    return

end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints!(ps_m::CanonicalModel,
                                   devices::PSY.FlattenIteratorWrapper{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                       D<:AbstractThermalDispatchForm,
                                                                       S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_range(ps_m,
                 range_data ,
                 Symbol("reactiverange_$(T)"),
                 Symbol("Q_$(T)"))

    return

end

"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function reactivepower_constraints!(ps_m::CanonicalModel,
                                   devices::PSY.FlattenIteratorWrapper{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                        D<:AbstractThermalFormulation,
                                                                        S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m,
                               range_data,
                               Symbol("reactiverange_$(T)"),
                               Symbol("Q_$(T)"),
                               Symbol("ON_$(T)"))

    return

end

### Constraints for Thermal Generation without commitment variables ####
"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints!(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalFormulation,
                                                                     S<:PM.AbstractPowerFormulation}

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
function _get_data_for_rocc(devices::PSY.FlattenIteratorWrapper{T},
                            resolution::Dates.Period) where {T<:PSY.ThermalGen}

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
        gen_tech = PSY.get_tech(g)
        name = PSY.get_name(g)
        non_binding_up = false
        non_binding_down = false
        ramplimits =  PSY.get_ramplimits(gen_tech)
        rating = PSY.get_rating(gen_tech)
        if !isnothing(ramplimits)
            p_lims = PSY.get_activepowerlimits(gen_tech)
            max_rate = abs(p_lims.min - p_lims.max)/minutes_per_period
            if (ramplimits.up*rating >= max_rate) & (ramplimits.down*rating >= max_rate)
                @info "Generator $(name) has a nonbinding ramp limits. Constraints Skipped"
                continue
            else
                idx += 1
            end
            set_name[idx] = name
            ramp_params[idx] = (up = ramplimits.up*rating*minutes_per_period,
                                down = ramplimits.down*rating*minutes_per_period)
            minmax_params[idx] = p_lims
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
                           devices::PSY.FlattenIteratorWrapper{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                    D<:AbstractThermalFormulation,
                                                    S<:PM.AbstractPowerFormulation}
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
                          devices::PSY.FlattenIteratorWrapper{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalDispatchForm,
                                                   S<:PM.AbstractPowerFormulation}
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
                          devices::PSY.FlattenIteratorWrapper{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalFormulation,
                                                   S<:PM.AbstractActivePowerFormulation}

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
                           devices::PSY.FlattenIteratorWrapper{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                    D<:AbstractThermalDispatchForm,
                                                    S<:PM.AbstractActivePowerFormulation}

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
function _get_data_for_tdc(devices::PSY.FlattenIteratorWrapper{T},
                           resolution::Dates.Period) where {T<:PSY.ThermalGen}

    steps_per_hour = 60/Dates.value(Dates.Minute(resolution))
    fraction_of_hour = 1/steps_per_hour
    lenght_devices = length(devices)
    set_name = Vector{String}(undef, lenght_devices)
    time_params = Vector{UpDown}(undef, lenght_devices)

    idx = 0
    for g in devices
        tech = PSY.get_tech(g)
        non_binding_up = false
        non_binding_down = false
        timelimits =  PSY.get_timelimits(tech)
        name = PSY.get_name(g)
        if !isnothing(timelimits)
            if (timelimits.up <= fraction_of_hour) & (timelimits.down <= fraction_of_hour)
                @info "Generator $(name) has a nonbinding time limits. Constraints Skipped"
            else
                idx += 1
            end
            set_name[idx] = name
            up_val = round(timelimits.up * steps_per_hour, RoundUp)
            down_val = round(timelimits.down * steps_per_hour, RoundUp)
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
                          devices::PSY.FlattenIteratorWrapper{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalFormulation,
                                                   S<:PM.AbstractPowerFormulation}

    parameters = model_has_parameters(ps_m)
    resolution = model_resolution(ps_m)
    duration_data = _get_data_for_tdc(devices, resolution)

    if !(isempty(duration_data[1]))

        key_on =  Symbol("duration_on_$(T)")
        key_off =  Symbol("duration_off_$(T)")
        if !(key_on in keys(ps_m.initial_conditions))
            @warn("Initial Conditions for Time Up/Down constraints not provided. This can lead to unwanted results")
            time_limits = duration_init(ps_m, devices, duration_data[1])
        end

        @assert length(duration_data[2]) == length(ps_m.initial_conditions[key_on])
        @assert length(duration_data[2]) == length(ps_m.initial_conditions[key_off])

       if parameters
            device_duration_param(ps_m,
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
                       devices::PSY.FlattenIteratorWrapper{T},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                           D<:AbstractThermalDispatchForm,
                                                           S<:PM.AbstractPowerFormulation}

    add_to_cost(ps_m,
                devices,
                Symbol("P_$(T)"),
                :variable)

    return

end


function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{T},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                           D<:AbstractThermalFormulation,
                                                           S<:PM.AbstractPowerFormulation}

    #Variable Cost component
    add_to_cost(ps_m, devices, Symbol("P_$(T)"), :variable)

    #Commitment Cost Components
    add_to_cost(ps_m, devices, Symbol("START_$(T)"), :startup)
    add_to_cost(ps_m, devices, Symbol("STOP_$(T)"), :shutdn)
    add_to_cost(ps_m, devices, Symbol("ON_$(T)"), :fixed)

    return

end
