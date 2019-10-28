########################### Thermal Generation Models ######################################

abstract type AbstractThermalFormulation <: AbstractDeviceFormulation end

abstract type AbstractThermalDispatchFormulation <: AbstractThermalFormulation end

abstract type AbstractThermalUnitCommitment <: AbstractThermalFormulation end

struct ThermalBasicUnitCommitment <: AbstractThermalUnitCommitment end

struct ThermalStandardUnitCommitment <: AbstractThermalUnitCommitment end

struct ThermalDispatch <: AbstractThermalDispatchFormulation end

struct ThermalRampLimited <: AbstractThermalDispatchFormulation end

struct ThermalDispatchNoMin <: AbstractThermalDispatchFormulation end

########################### Active Dispatch Variables ######################################

"""
This function add the variables for power generation output to the model
"""
function activepower_variables!(canonical::CanonicalModel,
                           devices::IS.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}


    add_variable(canonical,
                 devices,
                 Symbol("P_$(T)"),
                 false,
                 :nodal_balance_active;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> d.tech.activepowerlimits.min,
                 init_value = d -> PSY.get_activepower(PSY.get_tech(d)))

    return

end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables!(canonical::CanonicalModel,
                           devices::IS.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}

    add_variable(canonical,
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
function commitment_variables!(canonical::CanonicalModel,
                           devices::IS.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}

    time_steps = model_time_steps(canonical)
    var_names = [Symbol("ON_$(T)"), Symbol("START_$(T)"), Symbol("STOP_$(T)")]

    for v in var_names
        add_variable(canonical, devices, v, true)
    end

    return

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints!(canonical::CanonicalModel,
                                 devices::IS.FlattenIteratorWrapper{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalDispatchFormulation,
                                                                     S<:PM.AbstractPowerModel}

    range_data = [(PSY.get_name(g),  PSY.get_activepowerlimits(PSY.get_tech(g))) for g in devices]

    device_range(canonical,
                 range_data,
                 Symbol("activerange_$(T)"),
                 Symbol("P_$(T)"))
    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function activepower_constraints!(canonical::CanonicalModel,
                                 devices::IS.FlattenIteratorWrapper{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                      D<:AbstractThermalFormulation,
                                                                      S<:PM.AbstractPowerModel}

    range_data = [(PSY.get_name(g),  PSY.get_activepowerlimits(PSY.get_tech(g))) for g in devices]
    device_semicontinuousrange(canonical,
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
function activepower_constraints!(canonical::CanonicalModel,
                                  devices::IS.FlattenIteratorWrapper{T},
                                  device_formulation::Type{ThermalDispatchNoMin},
                                  system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     S<:PM.AbstractPowerModel}

    range_data = [(PSY.get_name(g), (min = 0.0, max=( PSY.get_activepowerlimits(PSY.get_tech(g))).max)) for g in devices]
    var_key = Symbol("P_$(T)")
    variable = var(canonical, var_key)

    # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
    for v in variable
        if JuMP.has_lower_bound(v)
            JuMP.set_lower_bound(v, 0.0)
        end
    end

    device_range(canonical,
                range_data,
                Symbol("activerange_$(T)"),
                Symbol("P_$(T)")
                )

    return

end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints!(canonical::CanonicalModel,
                                   devices::IS.FlattenIteratorWrapper{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                       D<:AbstractThermalDispatchFormulation,
                                                                       S<:PM.AbstractPowerModel}

    range_data = [(PSY.get_name(g),  PSY.get_reactivepowerlimits(PSY.get_tech(g))) for g in devices]

    device_range(canonical,
                 range_data ,
                 Symbol("reactiverange_$(T)"),
                 Symbol("Q_$(T)"))

    return

end

"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function reactivepower_constraints!(canonical::CanonicalModel,
                                   devices::IS.FlattenIteratorWrapper{T},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                        D<:AbstractThermalFormulation,
                                                                        S<:PM.AbstractPowerModel}

    range_data = [(PSY.get_name(g),  PSY.get_reactivepowerlimits(PSY.get_tech(g))) for g in devices]

    device_semicontinuousrange(canonical,
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
function commitment_constraints!(canonical::CanonicalModel,
                                 devices::IS.FlattenIteratorWrapper{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalFormulation,
                                                                     S<:PM.AbstractPowerModel}

    key = ICKey(DeviceStatus, T)

    if !(key in keys(canonical.initial_conditions))
        error("Initial status conditions not provided. This can lead to unwanted results")
    end

    device_commitment(canonical,
                     canonical.initial_conditions[key],
                     Symbol("commitment_$(T)"),
                     (Symbol("START_$(T)"),
                      Symbol("STOP_$(T)"),
                      Symbol("ON_$(T)"))
                      )

    return

end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(canonical::CanonicalModel,
                            devices::IS.FlattenIteratorWrapper{T},
                            device_formulation::Type{D}) where {T<:PSY.ThermalGen,
                                                                D<:AbstractThermalFormulation}

    status_init(canonical, devices)
    output_init(canonical, devices)
    duration_init(canonical, devices)

    return

end


function initial_conditions!(canonical::CanonicalModel,
                            devices::IS.FlattenIteratorWrapper{T},
                            device_formulation::Type{D}) where {T<:PSY.ThermalGen,
                                                                D<:AbstractThermalDispatchFormulation}

    output_init(canonical, devices)

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

    lenght_devices = length(initial_conditions)
    ini_conds = Vector{InitialCondition}(undef, lenght_devices)
    ramp_params = Vector{UpDown}(undef, lenght_devices)
    minmax_params = Vector{MinMax}(undef, lenght_devices)

    idx = 0
    for ic in initial_conditions
        g = ic.device
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
            ini_conds[idx] = ic
            ramp_params[idx] = (up = ramplimits.up*rating*minutes_per_period,
                                down = ramplimits.down*rating*minutes_per_period)
            minmax_params[idx] = p_lims
        end
    end

    if idx < lenght_devices
        deleteat!(ini_conds, idx+1:lenght_devices)
        deleteat!(ramp_params, idx+1:lenght_devices)
        deleteat!(minmax_params, idx+1:lenght_devices)
    end

    return ini_conds, ramp_params, minmax_params

end

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints!(canonical::CanonicalModel,
                           devices::IS.FlattenIteratorWrapper{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                    D<:AbstractThermalFormulation,
                                                    S<:PM.AbstractPowerModel}
    key = ICKey(DevicePower, T)

    if !(key in keys(canonical.initial_conditions))
        error("Initial Conditions for $(T) Rate of Change Constraints not in the model")
    end

    time_steps = model_time_steps(canonical)
    resolution = model_resolution(canonical)
    initial_conditions = get_initial_conditions(canonical, key)
    rate_data = _get_data_for_rocc(initial_conditions, resolution)
    ini_conds, ramp_params, minmax_params = _get_data_for_rocc(initial_conditions, resolution)

    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_mixedinteger_rateofchange(canonical,
                                         (ramp_params, minmax_params),
                                         ini_conds,
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

function ramp_constraints!(canonical::CanonicalModel,
                          devices::IS.FlattenIteratorWrapper{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalDispatchFormulation,
                                                   S<:PM.AbstractPowerModel}

    key = ICKey(DevicePower, T)

    if !(key in keys(canonical.initial_conditions))
        error("Initial Conditions for $(T) Rate of Change Constraints not in the model")
    end

    time_steps = model_time_steps(canonical)
    resolution = model_resolution(canonical)
    initial_conditions = get_initial_conditions(canonical, key)
    rate_data = _get_data_for_rocc(initial_conditions, resolution)
    ini_conds, ramp_params, minmax_params = _get_data_for_rocc(initial_conditions, resolution)

    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_linear_rateofchange(canonical,
                                  ramp_params,
                                  ini_conds,
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
function _get_data_for_tdc(initial_conditions_on::Vector{InitialCondition},
                           initial_conditions_off::Vector{InitialCondition},
                           resolution::Dates.Period)

    steps_per_hour = 60/Dates.value(Dates.Minute(resolution))
    fraction_of_hour = 1/steps_per_hour
    lenght_devices_on = length(initial_conditions_on)
    lenght_devices_off = length(initial_conditions_off)
    @assert lenght_devices_off == lenght_devices_on
    time_params = Vector{UpDown}(undef, lenght_devices_on)
    ini_conds = Matrix{InitialCondition}(undef, lenght_devices_on, 2)

    idx = 0
    for (ix, ic) in enumerate(initial_conditions_on)
        g = ic.device
        @assert g == initial_conditions_off[ix].device
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
            ini_conds[idx, 1] = ic
            ini_conds[idx, 2] = initial_conditions_off[ix]
            up_val = round(timelimits.up * steps_per_hour, RoundUp)
            down_val = round(timelimits.down * steps_per_hour, RoundUp)
            time_params[idx] = time_params[idx] = (up = up_val, down = down_val)
        end
    end

    if idx < lenght_devices_on
        ini_conds = ini_conds[1:idx,:]
        deleteat!(time_params, idx+1:lenght_devices_on)
    end

    return ini_conds, time_params

end

function time_constraints!(canonical::CanonicalModel,
                          devices::IS.FlattenIteratorWrapper{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalFormulation,
                                                   S<:PM.AbstractPowerModel}

    ic_keys = [ICKey(TimeDurationON, T), ICKey(TimeDurationOFF, T)]
    for key in ic_keys
        if !(key in keys(canonical.initial_conditions))
            error("Initial Conditions for $(T) Time Constraint not in the model")
        end
    end

    parameters = model_has_parameters(canonical)
    resolution = model_resolution(canonical)
    initial_conditions_on  = get_initial_conditions(canonical, ic_keys[1])
    initial_conditions_off = get_initial_conditions(canonical, ic_keys[2])
    ini_conds, time_params = _get_data_for_tdc(initial_conditions_on,
                                               initial_conditions_off,
                                               resolution)

    if !(isempty(ini_conds))
       if parameters
            device_duration_param(canonical,
                                time_params,
                                ini_conds,
                                Symbol("duration_$(T)"),
                                (Symbol("ON_$(T)"),
                                Symbol("START_$(T)"),
                                Symbol("STOP_$(T)"))
                                      )
        else
            device_duration_retrospective(canonical,
                                        time_params,
                                        ini_conds,
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

function cost_function(canonical::CanonicalModel,
                       devices::IS.FlattenIteratorWrapper{T},
                       ::Type{D},
                       ::Type{S}) where {T<:PSY.ThermalGen,
                                         D<:AbstractThermalDispatchFormulation,
                                         S<:PM.AbstractPowerModel}

    add_to_cost(canonical,
                devices,
                Symbol("P_$(T)"),
                :variable)

    return

end


function cost_function(canonical::CanonicalModel,
                       devices::IS.FlattenIteratorWrapper{T},
                       ::Type{D},
                       ::Type{S}) where {T<:PSY.ThermalGen,
                                         D<:AbstractThermalFormulation,
                                         S<:PM.AbstractPowerModel}

    #Variable Cost component
    add_to_cost(canonical, devices, Symbol("P_$(T)"), :variable)

    #Commitment Cost Components
    add_to_cost(canonical, devices, Symbol("START_$(T)"), :startup)
    add_to_cost(canonical, devices, Symbol("STOP_$(T)"), :shutdn)
    add_to_cost(canonical, devices, Symbol("ON_$(T)"), :fixed)

    return

end
