"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Symbol
    data_name::Union{Nothing, String}
end

function UpdateRef{T}(name::Symbol) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(name, nothing)
end

function UpdateRef{T}(
    name::AbstractString,
    data_name::Union{Nothing, String} = nothing,
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(Symbol(name), data_name)
end

function UpdateRef{T}(
    ::Type{U},
    variable_type::V,
) where {T <: JuMP.VariableRef, U <: PSY.Component, V <: VariableType}
    return UpdateRef{T}(U, V)
end

function UpdateRef{T}(
    ::Type{U},
    variable_type::Type{V},
) where {T <: JuMP.VariableRef, U <: PSY.Component, V <: VariableType}
    return UpdateRef{T}(encode_symbol(U, V), nothing)
end

function UpdateRef{T}(
    ::Type{U},
    name::AbstractString,
) where {T <: PJ.ParameterRef, U <: PSY.Component}
    return UpdateRef{T}(encode_symbol(U, name), nothing)
end

function UpdateRef{T}(
    name::AbstractString,
    data_name::AbstractString,
) where {T <: PSY.Component}
    # Combine these three fields together in order to guarantee uniqueness.
    return UpdateRef{T}(encode_symbol(T, name, data_name), data_name)
end

function get_data_name(ref::UpdateRef{T}) where {T <: PSY.Component}
    if ref.data_name === nothing
        throw(IS.InvalidValue("data_name is not defined for $ref"))
    end

    return ref.data_name
end
