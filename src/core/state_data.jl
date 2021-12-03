struct StateData
    values::DataFrames.DataFrame
    timestamps::Vector{Dates.DateTime}
end

get_timestamps_length(s::StateData) = length(s.timestamps)
get_data_resolution(s::StateData) = s.timestamps[2] - s.timestamps[1]
get_timestamps(s::StateData) = s.timestamps
get_state_values(s::StateData) = s.values

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
