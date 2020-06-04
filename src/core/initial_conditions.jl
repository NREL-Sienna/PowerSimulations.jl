struct ICKey{IC <: InitialConditionType, D <: PSY.Component}
    ic_type::Type{IC}
    device_type::Type{D}
end

struct InitialConditions
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

function has_initial_conditions(container::InitialConditions, key::ICKey)
    return key in keys(container.data)
end

function get_initial_conditions(container::InitialConditions, key::ICKey)
    initial_conditions = get(container.data, key, nothing)
    if isnothing(initial_conditions)
        throw(IS.InvalidValue("initial conditions are not stored for $(key)"))
    end

    return initial_conditions
end

function set_initial_conditions!(container::InitialConditions, key::ICKey, value)
    @debug "set_initial_condition" key
    container.data[key] = value
end

"""
Iterate over the keys and vectors of initial conditions.
"""
iterate_initial_conditions(container::InitialConditions) = pairs(container.data)
