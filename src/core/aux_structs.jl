"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Symbol
    accessor_func::Union{Nothing, String}
end

function UpdateRef{T}(name::Symbol) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(name, nothing)
end

function UpdateRef{T}(
    name::AbstractString,
    accessor_func::Union{Nothing, String} = nothing,
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(Symbol(name), accessor_func)
end

function UpdateRef{T}(
    ::Type{U},
    name::AbstractString,
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}, U <: PSY.Component}
    return UpdateRef{T}(encode_symbol(U, name), nothing)
end

function UpdateRef{T}(
    name::AbstractString,
    accessor_func::AbstractString,
) where {T <: PSY.Component}
    # Combine these three fields together in order to guarantee uniqueness.
    return UpdateRef{T}(encode_symbol(T, name, accessor_func), accessor_func)
end

function get_accessor_func(ref::UpdateRef{T}) where {T <: PSY.Component}
    if isnothing(ref.accessor_func)
        throw(IS.InvalidValue("accessor_func is not defined for $ref"))
    end

    return ref.accessor_func
end
