mutable struct StateData
    last_recorded_row::Int
    values::DataFrames.DataFrame
    timestamps::Vector{Dates.DateTime}
end

function StateData(values::DataFrames.DataFrame, timestamps::Vector{Dates.DateTime})
    return StateData(0, values, timestamps)
end

get_last_recorded_row(s::StateData) = s.last_recorded_row
get_timestamps_length(s::StateData) = length(s.timestamps)
get_data_resolution(s::StateData) = s.timestamps[2] - s.timestamps[1]
get_timestamps(s::StateData) = s.timestamps
get_state_values(s::StateData) = s.values
function get_last_update_timestamp(s::StateData)
    if s.last_recorded_row == 0
        return UNSET_INI_TIME
    end
    return s.timestamps[s.last_recorded_row]
end

sim.internal.simulation_state.system_state.variables[PowerSimulations.VariableKey{ActivePowerVariable, RenewableDispatch}("")].values[1,:] = vals.values[1, :]

function get_last_update_value(s.::StateData)
    return get_state_values(s)[s.last_recorded_row, :]
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
