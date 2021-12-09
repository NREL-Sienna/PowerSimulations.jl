mutable struct StateData
    last_recorded_row::Int
    values::DataFrames.DataFrame
    timestamps::Vector{Dates.DateTime}
    # Resolution is needed because StateData might have just one entry
    resolution::Dates.Period
end

function StateData(
    values::DataFrames.DataFrame,
    timestamps::Vector{Dates.DateTime},
    resolution::Dates.Period,
)
    return StateData(0, values, timestamps, resolution)
end

get_last_recorded_row(s::StateData) = s.last_recorded_row
Base.length(s::StateData) = length(s.timestamps)
get_data_resolution(s::StateData) = s.resolution
get_timestamps(s::StateData) = s.timestamps
_get_values(s::StateData) = s.values

function _get_last_updated_timestamp(s::StateData)
    if get_last_recorded_row(s) == 0
        return UNSET_INI_TIME
    end
    return get_timestamps(s)[get_last_recorded_row(s)]
end

function _get_state_value(s::StateData, date::Dates.DateTime)
    if _get_last_updated_timestamp(s) == date
        s_index = get_last_recorded_row(s)
    else
        s_index = findlast(get_timestamps(s) .<= date)
    end
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return _get_values(s)[s_index, :]
end

function get_last_recorded_value(s::StateData)
    if get_last_recorded_row(s) == 0
        error("The State hasn't been written yet")
    end
    return _get_values(s)[get_last_recorded_row(s), :]
end

function set_last_recorded_row(s::StateData, val::Int)
    s.last_recorded_row = val
    return
end

struct StateInfo
    duals::Dict{ConstraintKey, StateData}
    aux_variables::Dict{AuxVarKey, StateData}
    variables::Dict{VariableKey, StateData}
end

function StateInfo()
    return StateInfo(
        Dict{ConstraintKey, StateData}(),
        Dict{AuxVarKey, StateData}(),
        Dict{VariableKey, StateData}(),
    )
end

function get_state_keys(state::StateInfo)
    return Iterators.flatten(keys(getfield(state, f)) for f in fieldnames(StateInfo))
end

function get_state_data(state::StateInfo, key::VariableKey)
    return state.variables[key]
end

function get_state_data(state::StateInfo, key::AuxVarKey)
    return state.aux_variables[key]
end

function get_state_data(state::StateInfo, key::ConstraintKey)
    return state.duals[key]
end

function set_state_data(state::StateInfo, key::VariableKey, val::StateData)
    state.variables[key] = val
    return
end

function set_state_data(state::StateInfo, key::AuxVarKey, val::StateData)
    state.aux_variables[key] = val
    return
end

function set_state_data(state::StateInfo, key::ConstraintKey, val::StateData)
    state.duals[key] = val
    return
end

function get_state_data(
    state::StateInfo,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_state_data(state, ConstraintKey(T, U))
end

function get_state_data(
    state::StateInfo,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_state_data(state, VariableKey(T, U))
end

function get_state_data(
    state::StateInfo,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_state_data(state, AuxVarKey(T, U))
end

function get_state_values(state::StateInfo, key::OptimizationContainerKey)
    return _get_values(get_state_data(state, key))
end

function get_state_values(
    state::StateInfo,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_state_values(state, ConstraintKey(T, U))
end

function get_state_values(
    state::StateInfo,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_state_values(state, VariableKey(T, U))
end

function get_state_values(
    state::StateInfo,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_state_values(state, AuxVarKey(T, U))
end

function get_state_values(
    state::StateInfo,
    key::OptimizationContainerKey,
    date::Dates.DateTime,
)
    return _get_state_value(get_state_data(state, key), date)
end

function get_last_updated_timestamp(state::StateInfo, key::OptimizationContainerKey)
    return _get_last_updated_timestamp(get_state_data(state, key))
end

function get_last_update_value(state::StateInfo, key::OptimizationContainerKey)
    return get_last_recorded_value(get_state_data(state, key))
end
