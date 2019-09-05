######## Structs for Formulation feedforward ########
abstract type FeedForwardModel end

struct UpperBoundFF <: FeedForwardModel
    vars_prefix::Vector{Symbol}
end

UpperBoundFF(var::Symbol) = UpperBoundFF([var])
get_vars_prefix(p::UpperBoundFF) = p.vars_prefix

struct RangeFF <: FeedForwardModel
    lb_vars_prefix::Vector{Symbol}
    ub_vars_prefix::Vector{Symbol}
end

RangeFF(var_lb::Symbol, var_ub::Symbol) = RangeFF([var_lb], [var_ub])
get_vars_prefix(p::RangeFF) = (p.lb_var_prefix, p.lb_var_prefix)

struct SemiContinuousFF <: FeedForwardModel
    vars_prefix::Vector{Symbol}
    bin_prefix::Symbol
end

SemiContinuousFF(var::Symbol, bin_var::Symbol) = SemiContinuousFF([var], bin_var)

get_bin_prefix(p::SemiContinuousFF) = p.bin_prefix
get_vars_prefix(p::SemiContinuousFF) = p.vars_prefix

abstract type AbstractDeviceFormulation end

function _validate_device_formulation(device_model::Type{D}) where {D<:Union{AbstractDeviceFormulation, PSY.Device}}

    if !isconcretetype(device_model)
        throw(ArgumentError( "the device model must containt only concrete types, $(device_model) is an Abstract Type"))
    end

end

mutable struct DeviceModel{D<:PSY.Device,
                           B<:AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
    feedforward::Union{Nothing, FeedForwardModel}

    function DeviceModel(::Type{D},
                         ::Type{B},
                         feedforward::Union{Nothing, F}) where {D<:PSY.Device,
                                                                B<:AbstractDeviceFormulation,
                                                                F<:FeedForwardModel}

    _validate_device_formulation(D)
    _validate_device_formulation(B)

    new{D, B}(D, B, feedforward)

    end

end

function DeviceModel(::Type{D},
                     ::Type{B}) where {D<:PSY.Device,
                                       B<:AbstractDeviceFormulation}

                    _validate_device_formulation(D)
                    _validate_device_formulation(B)

    return DeviceModel(D, B, nothing)

end

