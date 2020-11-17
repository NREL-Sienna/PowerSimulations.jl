# UpdateRef needs to be substituted by a "key" to pre-define queries into the DataStore

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
    name::AbstractString,
) where {T <: Union{JuMP.VariableRef, PJ.ParameterRef}, U <: PSY.Component}
    return UpdateRef{T}(encode_symbol(U, name), nothing)
end


## This UpdateRef makes the updates from the TimeSeries
function UpdateRef{T}(
    name::AbstractString,
    data_label::AbstractString,
) where {T <: PSY.Component}
    # Combine these three fields together in order to guarantee uniqueness.
    return UpdateRef{T}(encode_symbol(T, name, data_label), data_label)
end

function get_data_label(ref::UpdateRef{T}) where {T <: PSY.Component}
    if isnothing(ref.data_label)
        throw(IS.InvalidValue("data_label is not defined for $ref"))
    end

    return ref.data_label
end
