struct ICKey{T <: InitialConditionType, U <: PSY.Component} <: OptimizationContainerKey
    entry_type::Type{T}
    component_type::Type{U}
    meta::String
end

function ICKey(::Type{T}, ::Type{U}) where {T <: InitialConditionType, U <: PSY.Component}
    return ICKey(T, U, CONTAINER_KEY_EMPTY_META)
end

mutable struct InitialConditions
    use_parameters::Bool
    data::Dict{ICKey, Vector{InitialCondition}}
end

function InitialConditions(;
    use_parameters = false,
    data = Dict{ICKey, Array{InitialCondition}}(),
)
    return InitialConditions(use_parameters, data)
end

get_use_parameters(container::InitialConditions) = container.use_parameters
set_use_parameters!(ini_cond::InitialConditions, val::Bool) = ini_cond.use_parameters = val

function has_initial_conditions(container::InitialConditions, key::ICKey)
    return key in keys(container.data)
end

function get_initial_conditions(container::InitialConditions, key::ICKey)
    initial_conditions = get(container.data, key, nothing)
    if initial_conditions === nothing
        throw(IS.InvalidValue("initial conditions are not stored for $(key)"))
    end

    return initial_conditions
end

function set_initial_conditions!(container::InitialConditions, key::ICKey, value)
    @debug "set_initial_condition_container" key
    container.data[key] = value
end

"""
Iterate over the keys and vectors of initial conditions.
"""
iterate_initial_conditions(container::InitialConditions) = pairs(container.data)
