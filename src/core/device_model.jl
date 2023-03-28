"""
Formulation type to augment the power balance constraint expression with a time series parameter
"""
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

  - `feedforward::Array{<:AbstractAffectFeedforward}` : use to pass parameters between models

# Example

thermal_gens = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
"""
mutable struct DeviceModel{D <: PSY.Device, B <: AbstractDeviceFormulation}
    feedforwards::Vector{<:AbstractAffectFeedforward}
    use_slacks::Bool
    duals::Vector{DataType}
    services::Vector{ServiceModel}
    time_series_names::Dict{Type{<:TimeSeriesParameter}, String}
    attributes::Dict{String, Any}

    function DeviceModel(
        ::Type{D},
        ::Type{B};
        feedforwards = Vector{AbstractAffectFeedforward}(),
        use_slacks = false,
        duals = Vector{DataType}(),
        time_series_names = get_default_time_series_names(D, B),
        attributes = get_default_attributes(D, B),
    ) where {D <: PSY.Device, B <: AbstractDeviceFormulation}
        _check_device_formulation(D)
        _check_device_formulation(B)
        new{D, B}(
            feedforwards,
            use_slacks,
            duals,
            Vector{ServiceModel}(),
            time_series_names,
            attributes,
        )
    end
end

get_component_type(
    ::DeviceModel{D, B},
) where {D <: PSY.Device, B <: AbstractDeviceFormulation} = D
get_formulation(
    ::DeviceModel{D, B},
) where {D <: PSY.Device, B <: AbstractDeviceFormulation} = B
get_feedforwards(m::DeviceModel) = m.feedforwards
get_services(m::DeviceModel) = m.services
get_services(::Nothing) = nothing
get_use_slacks(m::DeviceModel) = m.use_slacks
get_duals(m::DeviceModel) = m.duals
get_time_series_names(m::DeviceModel) = m.time_series_names
get_attributes(m::DeviceModel) = m.attributes
get_attribute(m::DeviceModel, key::String) = get(m.attributes, key, nothing)

function get_reference_bus(
    m::DeviceModel{T, U},
    d::T,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    return get_subnetworks_map(m)[d]
end

function _set_model!(
    dict::Dict,
    model::DeviceModel{D, B},
) where {D <: PSY.Device, B <: AbstractDeviceFormulation}
    key = Symbol(D)
    if haskey(dict, key)
        @warn "Overwriting $(D) existing model"
    end
    dict[key] = model
    return
end

has_service_model(model::DeviceModel) = !isempty(get_services(model))
