"""Formulation that fixes the injection values of devices"""
struct FixedOutput <: AbstractDeviceFormulation end

function _check_device_formulation(
    ::Type{D},
) where {D <: Union{AbstractDeviceFormulation, PSY.Device}}
    if !isconcretetype(D)
        throw(
            ArgumentError(
                "The device model must contain only concrete types, $(D) is an Abstract Type",
            ),
        )
    end
end

"""
Establishes the model for a particular device specified by type. Uses the keyword argument
feedforward to enable passing values between operation model at simulation time

# Arguments
-`::Type{D}`: Power System Device Type
-`::Type{B}`: Abstract Device Formulation

# Accepted Key Words
- `feedforward::Array{<:AbstractAffectFeedForward}` : use to pass parameters between models

# Example
```julia
thermal_gens = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
```
"""
mutable struct DeviceModel{D <: PSY.Device, B <: AbstractDeviceFormulation}
    feedforward::Union{Nothing, AbstractAffectFeedForward}
    use_slacks::Bool
    duals::Vector{DataType}
    services::Vector{ServiceModel}
    time_series_labels::Dict{Type{<:TimeSeriesParameter}, String}

    function DeviceModel(
        ::Type{D},
        ::Type{B};
        feedforward = nothing,
        use_slacks = false,
        duals = Vector{DataType}(),
        time_series_labels = _initialize_timeseries_labels(D, B),
    ) where {D <: PSY.Device, B <: AbstractDeviceFormulation}
        _check_device_formulation(D)
        _check_device_formulation(B)
        new{D, B}(
            feedforward,
            use_slacks,
            duals,
            Vector{ServiceModel}(),
            time_series_labels,
        )
    end
end

get_component_type(
    ::DeviceModel{D, B},
) where {D <: PSY.Device, B <: AbstractDeviceFormulation} = D
get_formulation(
    ::DeviceModel{D, B},
) where {D <: PSY.Device, B <: AbstractDeviceFormulation} = B
get_feedforward(m::DeviceModel) = m.feedforward
get_services(m::DeviceModel) = m.services
get_services(::Nothing) = nothing
get_use_slacks(m::DeviceModel) = m.use_slacks
get_duals(m::DeviceModel) = m.duals
get_time_series_labels(m::DeviceModel) = m.time_series_labels

DeviceModelForBranches = DeviceModel{<:PSY.Branch, <:AbstractDeviceFormulation}

function _set_model!(
    dict::Dict,
    model::DeviceModel{D, B},
) where {D <: PSY.Device, B <: AbstractDeviceFormulation}
    key = Symbol(D)
    if haskey(dict, key)
        @info("Overwriting $(D) existing model")
    end
    dict[key] = model
end

function _initialize_timeseries_labels(
    ::Type{D},
    ::Type{T},
) where {D <: PSY.Device, T <: AbstractDeviceFormulation}
    return Dict{Type{<:TimeSeriesParameter}, String}()
end
