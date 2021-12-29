mutable struct ValueState
    last_recorded_row::Int
    values::DataFrames.DataFrame
    timestamps::Vector{Dates.DateTime}
    # Resolution is needed because ValueState might have just one entry
    resolution::Dates.Period
    end_of_step_index::Int
end

function ValueState(
    values::DataFrames.DataFrame,
    timestamps::Vector{Dates.DateTime},
    resolution::Dates.Period,
    end_of_step_index::Int = 0,
)
    return ValueState(0, values, timestamps, resolution, end_of_step_index)
end

get_last_recorded_row(s::ValueState) = s.last_recorded_row
Base.length(s::ValueState) = length(s.timestamps)
get_data_resolution(s::ValueState) = s.resolution
get_timestamps(s::ValueState) = s.timestamps
_get_values(s::ValueState) = s.values

function get_column_names(::OptimizationContainerKey, s::ValueState)
    return DataFrames.names(_get_values(s))
end

function get_end_of_step_timestamp(s::ValueState)
    return get_timestamps(s)[s.end_of_step_index]
end

function _get_last_updated_timestamp(s::ValueState)
    if get_last_recorded_row(s) == 0
        return UNSET_INI_TIME
    end
    return get_timestamps(s)[get_last_recorded_row(s)]
end

function _get_state_value(s::ValueState, date::Dates.DateTime)
    if _get_last_updated_timestamp(s) == date
        s_index = get_last_recorded_row(s)
    else
        s_index = find_timestamp_index(get_timestamps(s), date)
    end
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return _get_values(s)[s_index, :]
end

function get_last_recorded_value(s::ValueState)
    if get_last_recorded_row(s) == 0
        error("The State hasn't been written yet")
    end
    return _get_values(s)[get_last_recorded_row(s), :]
end

function set_last_recorded_row!(s::ValueState, val::Int)
    s.last_recorded_row = val
    return
end

struct ValueStates
    duals::Dict{ConstraintKey, ValueState}
    aux_variables::Dict{AuxVarKey, ValueState}
    variables::Dict{VariableKey, ValueState}
    parameters::Dict{ParameterKey, ValueState}
    expressions::Dict{ExpressionKey, ValueState}
end

function ValueStates()
    return ValueStates(
        Dict{ConstraintKey, ValueState}(),
        Dict{AuxVarKey, ValueState}(),
        Dict{VariableKey, ValueState}(),
        Dict{ParameterKey, ValueState}(),
        Dict{ExpressionKey, ValueState}()
    )
end

function get_duals_values(state::ValueStates)
    return state.duals
end

function get_aux_variables_values(state::ValueStates)
    return state.aux_variables
end

function get_variables_values(state::ValueStates)
    return state.variables
end

function get_parameters_values(state::ValueStates)
    return state.parameters
end

function get_state_keys(state::ValueStates)
    return Iterators.flatten(keys(getfield(state, f)) for f in fieldnames(ValueStates))
end

function get_state_data(state::ValueStates, key::VariableKey)
    return state.variables[key]
end

function get_state_data(state::ValueStates, key::AuxVarKey)
    return state.aux_variables[key]
end

function get_state_data(state::ValueStates, key::ConstraintKey)
    return state.duals[key]
end

function get_state_data(state::ValueStates, key::ParameterKey)
    return state.parameters[key]
end

function get_state_data(state::ValueStates, key::ExpressionKey)
    return state.expressions[key]
end


function set_state_data!(state::ValueStates, key::VariableKey, val::ValueState)
    state.variables[key] = val
    return
end

function set_state_data!(state::ValueStates, key::AuxVarKey, val::ValueState)
    state.aux_variables[key] = val
    return
end

function set_state_data!(state::ValueStates, key::ConstraintKey, val::ValueState)
    state.duals[key] = val
    return
end

function set_state_data!(state::ValueStates, key::ParameterKey, val::ValueState)
    state.parameters[key] = val
    return
end

function set_state_data!(state::ValueStates, key::ExpressionKey, val::ValueState)
    state.expressions[key] = val
    return
end

function has_state_data(state::ValueStates, key::VariableKey)
    return haskey(state.variables, key)
end

function has_state_data(state::ValueStates, key::AuxVarKey)
    return haskey(state.aux_variables, key)
end

function has_state_data(state::ValueStates, key::ConstraintKey)
    return haskey(state.duals, key)
end

function has_state_data(state::ValueStates, key::ParameterKey)
    return haskey(state.parameters, key)
end

function has_state_data(state::ValueStates, key::ExpressionKey)
    return haskey(state.expressions, key)
end

function get_state_data(
    state::ValueStates,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_state_data(state, ConstraintKey(T, U))
end

function get_state_data(
    state::ValueStates,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_state_data(state, VariableKey(T, U))
end

function get_state_data(
    state::ValueStates,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_state_data(state, AuxVarKey(T, U))
end

function get_state_data(
    state::ValueStates,
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_state_data(state, ParameterKey(T, U))
end

function get_state_data(
    state::ValueStates,
    ::T,
    ::Type{U},
) where {T <: ExpressionType, U <: Union{PSY.Component, PSY.System}}
    return get_state_data(state, ExpressionKey(T, U))
end

function get_state_values(state::ValueStates, key::OptimizationContainerKey)
    return _get_values(get_state_data(state, key))
end

function get_state_values(
    state::ValueStates,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_state_values(state, ConstraintKey(T, U))
end

function get_state_values(
    state::ValueStates,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_state_values(state, VariableKey(T, U))
end

function get_state_values(
    state::ValueStates,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_state_values(state, AuxVarKey(T, U))
end

function get_state_values(
    state::ValueStates,
    ::T,
    ::Type{U},
) where {T <: ExpressionType, U <: Union{PSY.Component, PSY.System}}
    return get_state_values(state, ExpressionKey(T, U))
end

function get_state_values(
    state::ValueStates,
    key::OptimizationContainerKey,
    date::Dates.DateTime,
)
    return _get_state_value(get_state_data(state, key), date)
end

function get_last_updated_timestamp(state::ValueStates, key::OptimizationContainerKey)
    return _get_last_updated_timestamp(get_state_data(state, key))
end

function get_last_update_value(state::ValueStates, key::OptimizationContainerKey)
    return get_last_recorded_value(get_state_data(state, key))
end
