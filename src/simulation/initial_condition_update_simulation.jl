function update_initial_conditions!(
    ics::Vector{T},
    state::SimulationState,
    ::Dates.Period,
) where {
    T <:
    InitialCondition{InitialTimeDurationOn, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    for ic in ics
        var_val = get_system_state_value(state, TimeDurationOn(), get_component_type(ic))
        set_ic_quantity!(ic, var_val[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    state::SimulationState,
    ::Dates.Period,
) where {
    T <: InitialCondition{
        InitialTimeDurationOff,
        S,
    },
} where {S <: Union{Float64, PJ.ParameterRef}}
    for ic in ics
        var_val = get_system_state_value(state, TimeDurationOff(), get_component_type(ic))
        set_ic_quantity!(ic, var_val[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    state::SimulationState,
    ::Dates.Period,
) where {T <: InitialCondition{DevicePower, S}} where {S <: Union{Float64, PJ.ParameterRef}}
    for ic in ics
        comp_name = get_component_name(ic)
        comp_type = get_component_type(ic)
        status_val = get_system_state_value(state, OnVariable(), comp_type)[comp_name]
        var_val = get_system_state_value(state, ActivePowerVariable(), comp_type)[comp_name]
        if status_val > 0
            comp = get_component(ic)
            @assert_op var_val <= PSY.get_active_power_limits(comp).max
            @assert_op var_val >= PSY.get_active_power_limits(comp).min
            set_ic_quantity!(ic, var_val)
        else
            @assert isapprox(var_val, 0.0, atol = ABSOLUTE_TOLERANCE) "status and power don't match"
            set_ic_quantity!(ic, 0.0)
        end
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    state::SimulationState,
    ::Dates.Period,
) where {
    T <: InitialCondition{DeviceStatus, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    for ic in ics
        var_val = get_system_state_value(state, OnVariable(), get_component_type(ic))
        set_ic_quantity!(ic, var_val[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    state::SimulationState,
    ::Dates.Period,
) where {
    T <:
    InitialCondition{DeviceAboveMinPower, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    for ic in ics
        var_val = get_system_state_value(
            state,
            PowerAboveMinimumVariable(),
            get_component_type(ic),
        )
        set_ic_quantity!(ic, var_val[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    state::SimulationState,
    ::Dates.Period,
) where {
    T <:
    InitialCondition{InitialEnergyLevel, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    for ic in ics
        var_val = get_system_state_value(state, EnergyVariable(), get_component_type(ic))
        set_ic_quantity!(ic, var_val[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    state::SimulationState,
    ::Dates.Period,
) where {
    T <:
    InitialCondition{InitialEnergyLevelUp, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    for ic in ics
        var_val = get_system_state_value(state, EnergyVariableUp(), get_component_type(ic))
        set_ic_quantity!(ic, var_val[get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    ics::Vector{T},
    state::SimulationState,
    ::Dates.Period,
) where {
    T <: InitialCondition{
        InitialEnergyLevelDown,
        S,
    },
} where {S <: Union{Float64, PJ.ParameterRef}}
    for ic in ics
        var_val =
            get_system_state_value(state, EnergyVariableDown(), get_component_type(ic))
        set_ic_quantity!(ic, var_val[get_component_name(ic)])
    end
    return
end