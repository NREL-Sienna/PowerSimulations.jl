const _TypeContainer = Dict{Tuple{Symbol, Symbol}, DataType}
struct TypeContainer{T}
    data::_TypeContainer

    function TypeContainer{T}() where T
        return new{T}(_TypeContainer())
    end
end

#struct TypeRegistrations{T <: Union{PSY.System, PSY.Component}, U <: ConstraintType, V <: ParameterType, W <: VariableType}
struct TypeRegistrations
    component_types::TypeContainer{<:PSY.Component}
    constraint_types::TypeContainer{<: ConstraintType}
    parameter_types::TypeContainer{<: ParameterType}
    variable_types::TypeContainer{<: VariableType}
end

function TypeRegistrations(
    component_types = TypeContainer{PSY.Component}(),
    constraint_types = TypeContainer{ConstraintType}(),
    parameter_types = TypeContainer{ParameterType}(),
    variable_types = TypeContainer{VariableType}(),
)
    return TypeRegistrations(
        component_types,
        constraint_types,
        parameter_types,
        variable_types,
    )
end

"""
Registers types that can be serialized and deserialized.
"""
function register_types!(
    component_types = [],
    constraint_types = [],
    parameter_types = [],
    variable_types = [],
)
    register_types!(
        g_registrations,
        component_types = component_types,
        constraint_types = constraint_types,
        parameter_types = parameter_types,
        variable_types = variable_types,
    )
end

const g_registrations = TypeRegistrations()

function register_types!(
    registrations::TypeRegistrations,
    component_types = [],
    constraint_types = [],
    parameter_types = [],
    variable_types = [],
)
    _register_types!(registrations, component_types, :component_types)
    _register_types!(registrations, constraint_types, :constraint_types)
    _register_types!(registrations, parameter_types, :parameter_types)
    _register_types!(registrations, variable_types, :variable_types)
end

"""
Unregister all registered types.
"""
function empty_registrations!()
    empty!(g_registrations)
end

function Base.empty!(registrations::TypeRegistrations)
    empty!(registrations.component_types)
    empty!(registrations.constraint_types)
    empty!(registrations.parameter_types)
    empty!(registrations.variable_types)
    @info "Emptied all type registrations."
end

function _register_types!(registrations::TypeRegistrations, types, field_name)
    container = getproperty(registrations, field_name)
    for type in types
        key = _make_key(type)
        if haskey(container, key)
            if type == container[key]
                continue
            end
            throw(ArgumentError("$key is already stored for $field_name"))
        end
        container[key] = type
        @debug "Registered $field_name $key" _group = LOG_GROUP_TYPE_REGISTRATIONS
    end
end

function _make_key(::Type{T}) where {T}
    # Note that this could have periods if there are submodules.
    module_name = string(parentmodule(T))
    type_name = string(T)
    return (module_name, type_name)
end
