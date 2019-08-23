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
function activepower_variables!(canonical_model::CanonicalModel,
                           devices::PSY.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}


    add_variable(canonical_model,
                 devices,
                 Symbol("P_$(T)"),
                 false,
                 :nodal_balance_active;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0.0,
                 init_value = d -> PSY.get_tech(d) |> PSY.get_activepower)

    return

end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables!(canonical_model::CanonicalModel,
                           devices::PSY.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}

    add_variable(canonical_model,
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
function commitment_variables!(canonical_model::CanonicalModel,
                           devices::PSY.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}

    time_steps = model_time_steps(canonical_model)
    var_names = [Symbol("ON_$(T)"), Symbol("START_$(T)"), Symbol("STOP_$(T)")]

    for v in var_names
        add_variable(canonical_model, devices, v, true)
    end

    return

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints!(canonical_model::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalDispatchForm,
                                                                     S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]

    device_range(canonical_model,
                 range_data,
                 Symbol("activerange_$(T)"),
                 Symbol("P_$(T)"))
    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function activepower_constraints!(canonical_model::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                      D<:AbstractThermalFormulation,
                                                                      S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]
    device_semicontinuousrange(canonical_model,
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
function activepower_constraints!(canonical_model::CanonicalModel,
                                  devices::PSY.FlattenIteratorWrapper{T},
                                  device_formulation::Type{ThermalDispatchNoMin},
                                  system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), (min = 0.0, max=(PSY.get_tech(g) |> PSY.get_activepowerlimits).max)) for g in devices]

    if model_runs_sequentially(canonical_model)
        device_semicontinuousrange_param(canonical_model,
                                         range_data,
                                         Symbol("activerange_$(T)"),
                                         Symbol("P_$(T)"),
                                         RefParam{JuMP.VariableRef}(Symbol("ON_$(T)")))
    else
        device_range(canonical_model,
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
function reactivepower_constraints!(canonical_model::CanonicalModel,
                                   devices::PSY.FlattenIteratorWrapper{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                       D<:AbstractThermalDispatchForm,
                                                                       S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_range(canonical_model,
                 range_data ,
                 Symbol("reactiverange_$(T)"),
                 Symbol("Q_$(T)"))

    return

end

"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function reactivepower_constraints!(canonical_model::CanonicalModel,
                                   devices::PSY.FlattenIteratorWrapper{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                        D<:AbstractThermalFormulation,
                                                                        S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_semicontinuousrange(canonical_model,
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
function commitment_constraints!(canonical_model::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalFormulation,
                                                                     S<:PM.AbstractPowerFormulation}

    key = Symbol("status_$(T)")
    
    if !(key in keys(canonical_model.initial_conditions)) 
        @warn("Initial status conditions not provided. This can lead to unwanted results")
        device_name = map(x-> PSY.get_name(x), devices)
        status_init(canonical_model, devices, device_name)
    else
        status_miss = missing_init_cond(canonical_model.initial_conditions[key], devices)
        if !isnothing(status_miss)
            @warn("Initial status conditions not provided. This can lead to unwanted results")
            status_init(canonical_model, devices, status_miss)
        end
    end

    device_commitment(canonical_model,
                      canonical_model.initial_conditions[key],
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
function _get_data_for_rocc(initial_conditions::Vector{InitialCondition},
                            resolution::Dates.Period)

    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        minutes_per_period = Dates.value(Dates.Second(resolution))/60
    end

    devices = map(x-> x.device, initial_conditions)
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
function ramp_constraints!(canonical_model::CanonicalModel,
                           devices::PSY.FlattenIteratorWrapper{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                    D<:AbstractThermalFormulation,
                                                    S<:PM.AbstractPowerFormulation}
    time_steps = model_time_steps(canonical_model)
    resolution = model_resolution(canonical_model)

    key = Symbol("output_$(T)")

    if !(key in keys(canonical_model.initial_conditions))
        @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
        device_name = map(x-> PSY.get_name(x), devices)
        output_init(canonical_model, devices, device_name)
    else
        ramp_miss = missing_init_cond(canonical_model.initial_conditions[key], devices)
        if !isnothing(ramp_miss)
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(canonical_model, devices, ramp_miss)
        end
    end

    rate_data = _get_data_for_rocc(canonical_model.initial_conditions[key], resolution)
    canonical_model.initial_conditions[key] = filter_init_cond(canonical_model.initial_conditions[key],
                                                                rate_data[1])

    if !isempty(rate_data[1])
        @assert length(rate_data[2]) == length(canonical_model.initial_conditions[key])
        # Here goes the reactive power ramp limits
        device_mixedinteger_rateofchange(canonical_model,
                                        rate_data,
                                        canonical_model.initial_conditions[key],
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

function ramp_constraints!(canonical_model::CanonicalModel,
                          devices::PSY.FlattenIteratorWrapper{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalDispatchForm,
                                                   S<:PM.AbstractPowerFormulation}
    time_steps = model_time_steps(canonical_model)
    resolution = model_resolution(canonical_model)

    key = Symbol("output_$(T)")

    if !(key in keys(canonical_model.initial_conditions))
        @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
        device_name = map(x-> PSY.get_name(x), devices)
        output_init(canonical_model, devices,device_name)
    else
        ramp_miss = missing_init_cond(canonical_model.initial_conditions[key], devices)
        if !isnothing(ramp_miss)
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(canonical_model,devices, ramp_miss)
        end
    end

    rate_data = _get_data_for_rocc(canonical_model.initial_conditions[key], resolution)
    canonical_model.initial_conditions[key] = filter_init_cond(canonical_model.initial_conditions[key],
                                                                rate_data[1])
    if !isempty(rate_data[1])
        @assert length(rate_data[2]) == length(canonical_model.initial_conditions[key])

        # Here goes the reactive power ramp limits
        device_linear_rateofchange(canonical_model,
                                   (rate_data[1], rate_data[2]),
                                   canonical_model.initial_conditions[key],
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
function ramp_constraints!(canonical_model::CanonicalModel,
                          devices::PSY.FlattenIteratorWrapper{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalFormulation,
                                                   S<:PM.AbstractActivePowerFormulation}

    resolution = model_resolution(canonical_model)

    key = Symbol("output_$(T)")

    if !(key in keys(canonical_model.initial_conditions))
        @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
        device_name = map(x-> PSY.get_name(x), devices)
        output_init(canonical_model, devices, device_name)
    else
        ramp_miss = missing_init_cond(canonical_model.initial_conditions[key], devices)
        if !isnothing(ramp_miss)
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(canonical_model, devices, ramp_miss)
        end
    end

    rate_data = _get_data_for_rocc(canonical_model.initial_conditions[key], resolution)
    canonical_model.initial_conditions[key] = filter_init_cond(canonical_model.initial_conditions[key],
                                                                rate_data[1])

    if !isempty(rate_data[1])
        @assert length(rate_data[2]) == length(canonical_model.initial_conditions[key])

        device_mixedinteger_rateofchange(canonical_model,
                                        rate_data,
                                        canonical_model.initial_conditions[key],
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


function ramp_constraints!(canonical_model::CanonicalModel,
                           devices::PSY.FlattenIteratorWrapper{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                    D<:AbstractThermalDispatchForm,
                                                    S<:PM.AbstractActivePowerFormulation}

    resolution = model_resolution(canonical_model)
    key = Symbol("output_$(T)")

    if !(key in keys(canonical_model.initial_conditions))
        @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
        device_name = map(x-> PSY.get_name(x), devices)
        output_init(canonical_model, devices,device_name)
    else
        ramp_miss = missing_init_cond(canonical_model.initial_conditions[key], devices)
        if !isnothing(ramp_miss)
            @warn("Initial Conditions for Rate of Change Constraints not provided. This can lead to unwanted results")
            output_init(canonical_model,devices, ramp_miss)
        end
    end

    rate_data = _get_data_for_rocc(canonical_model.initial_conditions[key], resolution)
    canonical_model.initial_conditions[key] = filter_init_cond(canonical_model.initial_conditions[key],
                                                                rate_data[1])
    if !isempty(rate_data[1])
        @assert length(rate_data[2]) == length(canonical_model.initial_conditions[key])

        device_linear_rateofchange(canonical_model,
                                    (rate_data[1], rate_data[2]),
                                    canonical_model.initial_conditions[key],
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
function _get_data_for_tdc(initial_conditions::Vector{InitialCondition},
                           resolution::Dates.Period) 

    steps_per_hour = 60/Dates.value(Dates.Minute(resolution))
    fraction_of_hour = 1/steps_per_hour
    devices = map(x-> x.device, initial_conditions)
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

function missing_init_cond(initial_conditions::Vector{InitialCondition},
                            devices::PSY.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}
    
    device_names = map(x-> PSY.get_name(x), devices)
    if isempty(initial_conditions)
        return device_names
    else
        init_cond_devices = map(x-> PSY.get_name(x.device), initial_conditions)
        missing_device = filter(x-> !in(x,init_cond_devices),device_names)

        if isempty(missing_device)
            return nothing
        else
            return missing_device
        end
    end
end

function filter_init_cond(initial_conditions::Vector{InitialCondition},
                            set_name::Vector{String})
    fil_init_ = filter(x-> in(PSY.get_name(x.device),set_name), initial_conditions)
    return fil_init_
end

function time_constraints!(canonical_model::CanonicalModel,
                          devices::PSY.FlattenIteratorWrapper{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalFormulation,
                                                   S<:PM.AbstractPowerFormulation}

    parameters = model_has_parameters(canonical_model)
    resolution = model_resolution(canonical_model)
    
    key_on =  Symbol("duration_on_$(T)")
    key_off =  Symbol("duration_off_$(T)")

    if !(key_on in keys(canonical_model.initial_conditions))
        @warn("Initial Conditions for Minimum Up Time constraints not provided. This can lead to unwanted results")
        device_name = map(x-> PSY.get_name(x), devices)
        duration_init_on(canonical_model, devices, device_name )
    else
        dur_on_miss = missing_init_cond(canonical_model.initial_conditions[key_on], devices)
        if !isnothing(dur_on_miss)
            @warn("Initial Conditions for Minimum Up Time constraints not provided. This can lead to unwanted results")
            duration_init_on(canonical_model, devices, dur_on_miss)
        end
    end

    if !(key_off in keys(canonical_model.initial_conditions))
        @warn("Initial Conditions for Minimum Down Time constraints not provided. This can lead to unwanted results")
        device_name = map(x-> PSY.get_name(x), devices)
        duration_init_off(canonical_model, devices, device_name)
    else
        dur_off_miss = missing_init_cond(canonical_model.initial_conditions[key_off], devices)
        if !isnothing(dur_off_miss)
            @warn("Initial Conditions for Minimum Down Time constraints not provided. This can lead to unwanted results")
            duration_init_off(canonical_model, devices, dur_off_miss)
        end
    end

    sort!(canonical_model.initial_conditions[key_on],by=x-> PSY.get_name(x.device))
    sort!(canonical_model.initial_conditions[key_off],by=x-> PSY.get_name(x.device))
    duration_data = _get_data_for_tdc(canonical_model.initial_conditions[key_off], resolution)

    canonical_model.initial_conditions[key_off] = filter_init_cond(canonical_model.initial_conditions[key_off],
                                                                    duration_data[1])
    canonical_model.initial_conditions[key_on] = filter_init_cond(canonical_model.initial_conditions[key_on],
                                                                    duration_data[1])                                                                   

    if !(isempty(duration_data[1]))

        @assert length(duration_data[2]) == length(canonical_model.initial_conditions[key_on])
        @assert length(duration_data[2]) == length(canonical_model.initial_conditions[key_off])

       if parameters
            device_duration_param(canonical_model,
                                duration_data[1],
                                duration_data[2],
                                canonical_model.initial_conditions[key_on],
                                canonical_model.initial_conditions[key_off],
                                Symbol("duration_$(T)"),
                                (Symbol("ON_$(T)"),
                                Symbol("START_$(T)"),
                                Symbol("STOP_$(T)"))
                                      )
        else
            device_duration_retrospective(canonical_model,
                                        duration_data[1],
                                        duration_data[2],
                                        canonical_model.initial_conditions[key_on],
                                        canonical_model.initial_conditions[key_off],
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

function cost_function(canonical_model::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{T},
                       ::Type{D},
                       ::Type{S}) where {T<:PSY.ThermalGen,
                                         D<:AbstractThermalDispatchForm,
                                         S<:PM.AbstractPowerFormulation}

    add_to_cost(canonical_model,
                devices,
                Symbol("P_$(T)"),
                :variable)

    return

end


function cost_function(canonical_model::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{T},
                       ::Type{D},
                       ::Type{S}) where {T<:PSY.ThermalGen,
                                         D<:AbstractThermalFormulation,
                                         S<:PM.AbstractPowerFormulation}

    #Variable Cost component
    add_to_cost(canonical_model, devices, Symbol("P_$(T)"), :variable)

    #Commitment Cost Components
    add_to_cost(canonical_model, devices, Symbol("START_$(T)"), :startup)
    add_to_cost(canonical_model, devices, Symbol("STOP_$(T)"), :shutdn)
    add_to_cost(canonical_model, devices, Symbol("ON_$(T)"), :fixed)

    return

end
