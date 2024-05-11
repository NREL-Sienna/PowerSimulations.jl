
################## ic updates from store for emulation problems simulation #################

function update_initial_conditions!(
    ics::Vector{T},
    store::EmulationModelStore,
    ::Dates.Millisecond,
) where {
    T <: InitialCondition{InitialTimeDurationOn, S},
} where {S <: Union{Float64, JuMP.VariableRef}}
    for ic in ics
        var_val = get_value(store, TimeDurationOn(), get_component_type(ic))
        set_ic_quantity!(ic, get_last_recorded_value(var_val)[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    store::EmulationModelStore,
    ::Dates.Millisecond,
) where {
    T <: InitialCondition{InitialTimeDurationOff, S},
} where {S <: Union{Float64, JuMP.VariableRef}}
    for ic in ics
        var_val = get_value(store, TimeDurationOff(), get_component_type(ic))
        set_ic_quantity!(ic, get_last_recorded_value(var_val)[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    store::EmulationModelStore,
    ::Dates.Millisecond,
) where {
    T <: InitialCondition{DevicePower, S},
} where {S <: Union{Float64, JuMP.VariableRef}}
    for ic in ics
        var_val = get_value(store, ActivePowerVariable(), get_component_type(ic))
        set_ic_quantity!(ic, get_last_recorded_value(var_val)[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    store::EmulationModelStore,
    ::Dates.Millisecond,
) where {
    T <: InitialCondition{DeviceStatus, S},
} where {S <: Union{Float64, JuMP.VariableRef}}
    for ic in ics
        var_val = get_value(store, OnVariable(), get_component_type(ic))
        set_ic_quantity!(ic, get_last_recorded_value(var_val)[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    store::EmulationModelStore,
    ::Dates.Millisecond,
) where {
    T <: InitialCondition{DeviceAboveMinPower, S},
} where {S <: Union{Float64, JuMP.VariableRef}}
    for ic in ics
        var_val =
            get_value(store, PowerAboveMinimumVariable(), get_component_type(ic))
        set_ic_quantity!(ic, get_last_recorded_value(var_val)[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    store::EmulationModelStore,
    ::Dates.Millisecond,
) where {
    T <: InitialCondition{AreaControlError, S},
} where {S <: Union{Float64, JuMP.VariableRef}}
    for ic in ics
        var_val = get_value(store, AreaMismatchVariable(), get_component_type(ic))
        set_ic_quantity!(ic, get_last_recorded_value(var_val)[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    store::EmulationModelStore,
    ::Dates.Millisecond,
) where {
    T <: InitialCondition{InitialEnergyLevel, S},
} where {S <: Union{Float64, JuMP.VariableRef}}
    for ic in ics
        var_val = get_value(store, EnergyVariable(), get_component_type(ic))
        set_ic_quantity!(ic, get_last_recorded_value(var_val)[get_component_name(ic)])
    end
    return
end
