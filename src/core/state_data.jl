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
get_state_values(s::StateData) = s.values

function get_last_update_timestamp(s::StateData)
    if get_last_recorded_row(s) == 0
        return UNSET_INI_TIME
    end
    return get_timestamps(s)[get_last_recorded_row(s)]
end

function get_last_update_value(s::StateData, key::OptimizationContainerKey)
    if get_last_recorded_row(s) == 0
        error("The State hasn't been written yet")
    end
    return get_state_values(get_state_data(s, key))[get_last_recorded_row(s), :]
end

function get_state_value(s::StateData, date::Dates.DateTime)
    state_data_index = findlast(get_timestamps(s) .<= date)
    return get_state_values(s)[state_data_index, :]
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

function get_state_data(state::StateInfo, key::VariableKey)
    return state.variables[key]
end

function get_state_data(state::StateInfo, key::AuxVarKey)
    return state.aux_variables[key]
end

function get_state_data(state::StateInfo, key::ConstraintKey)
    return state.duals[key]
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

function get_state_value(
    state::StateInfo,
    key::OptimizationContainerKey,
    date::Dates.DateTime,
)
    state_data = get_state_data(state, key)
    if get_last_update_timestamp(state_data) == date
        state_data_index = get_last_recorded_row(state_data)
    else
        state_data_index = findlast(get_timestamps(state_data) .<= date)
    end
    if isnothing(state_data_index)
        error("Request time stamp $date not in the state")
    end
    return get_state_values(state_data)[state_data_index, :]
end
