"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Union{Symbol, Tuple{Symbol, Symbol}}
    data_label::Union{Nothing, String}
end

function UpdateRef{T}(name::Symbol) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(name, nothing)
end

function UpdateRef{T}(
    name::Tuple{Symbol, Symbol},
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(name, nothing)
end

function UpdateRef{T}(
    name::AbstractString,
    data_label::Union{Nothing, String} = nothing,
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(Symbol(name), data_label)
end

function UpdateRef{T}(
    name::Tuple{String, String},
    data_label::Union{Nothing, String} = nothing,
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}}
    return UpdateRef{T}(Symbol.(name), data_label)
end

function UpdateRef{T}(
    ::Type{U},
    name::AbstractString,
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}, U <: PSY.Component}
    return UpdateRef{T}(encode_symbol(U, name), nothing)
end

function UpdateRef{T}(
    ::Type{U},
    name::Tuple{AbstractString, AbstractString},
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}, U <: PSY.Component}
    return UpdateRef{T}((encode_symbol(U, name[1]), encode_symbol(U, name[2])), nothing)
end

function UpdateRef{T}(
    name::AbstractString,
    data_label::AbstractString,
) where {T <: PSY.Component}
    # Combine these three fields together in order to guarantee uniqueness.
    return UpdateRef{T}(encode_symbol(T, name, data_label), data_label)
end

function UpdateRef{T}(
    name::Tuple{AbstractString, AbstractString},
    data_label::AbstractString,
) where {T <: PSY.Component}
    # Combine these three fields together in order to guarantee uniqueness.
    return UpdateRef{T}(
        (encode_symbol(T, name[1], data_label), encode_symbol(T, name[2], data_label)),
        data_label,
    )
end

function get_data_label(ref::UpdateRef{T}) where {T <: PSY.Component}
    if ref.data_label === nothing
        throw(IS.InvalidValue("data_label is not defined for $ref"))
    end

    return ref.data_label
end
