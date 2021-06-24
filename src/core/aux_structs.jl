"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Symbol
    data_label::Union{Nothing, String}
end

function UpdateRef{T}(name::Symbol) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(name, nothing)
end

function UpdateRef{T}(
    name::AbstractString,
    data_label::Union{Nothing, String} = nothing,
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(Symbol(name), data_label)
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
    data_label::AbstractString,
) where {T <: PSY.Component}
    # Combine these three fields together in order to guarantee uniqueness.
    return UpdateRef{T}(encode_symbol(T, name, data_label), data_label)
end

function get_data_label(ref::UpdateRef{T}) where {T <: PSY.Component}
    if ref.data_label === nothing
        throw(IS.InvalidValue("data_label is not defined for $ref"))
    end

    return ref.data_label
end
