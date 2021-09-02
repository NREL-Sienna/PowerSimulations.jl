"""
Abstract type for Service Formulations (a.k.a Models)

# Example
```julia
import PowerSimulations
const PSI = PowerSimulations
struct MyServiceFormulation <: PSI.AbstractServiceFormulation
```
"""
abstract type AbstractServiceFormulation end
abstract type AbstractReservesFormulation <: AbstractServiceFormulation end

function _check_service_formulation(
    ::Type{D},
) where {D <: Union{AbstractServiceFormulation, PSY.Service}}
    if !isconcretetype(D)
        throw(
            ArgumentError(
                "The service model must contain only concrete types, $(D) is an Abstract Type",
            ),
        )
    end
end

"""
Establishes the model for a particular services specified by type. Uses the keyword argument
`use_service_name` to assign the model to a service with the same name as the name in the
template. Uses the keyword argument feedforward to enable passing values between operation
model at simulation time

# Arguments
-`::Type{D}`: Power System Service Type
-`::Type{B}`: Abstract Service Formulation

# Accepted Key Words
- `feedforward::Array{<:AbstractAffectFeedForward}` : use to pass parameters between models
- `use_service_name::Bool` : use the name as the name for the service

# Example
```julia
reserves = ServiceModel(PSY.VariableReserve{PSY.ReserveUp}, RangeReserve)
```
"""
mutable struct ServiceModel{D <: PSY.Service, B <: AbstractServiceFormulation}
    feedforward::Union{Nothing, AbstractAffectFeedForward}
    service_name::String
    use_slacks::Bool
    duals::Vector{DataType}
    time_series_names::Dict{Type{<:TimeSeriesParameter}, String}
    attributes::Dict{String, Any}
    contributing_devices_map::Dict{Type{<:PSY.Component}, Vector{<:PSY.Component}}
    function ServiceModel(
        ::Type{D},
        ::Type{B},
        service_name::String;
        use_slacks = false,
        feedforward = nothing,
        duals = Vector{DataType}(),
        time_series_names = initialize_timeseries_names(D, B),
        attributes = initialize_attributes(D, B),
        contributing_devices_map = Dict{Type{<:PSY.Component}, Vector{<:PSY.Component}}(),
    ) where {D <: PSY.Service, B <: AbstractServiceFormulation}
        _check_service_formulation(D)
        _check_service_formulation(B)
        new{D, B}(
            feedforward,
            service_name,
            use_slacks,
            duals,
            time_series_names,
            attributes,
            contributing_devices_map,
        )
    end
end

get_component_type(
    ::ServiceModel{D, B},
) where {D <: PSY.Service, B <: AbstractServiceFormulation} = D
get_formulation(
    ::ServiceModel{D, B},
) where {D <: PSY.Service, B <: AbstractServiceFormulation} = B
get_feedforward(m::ServiceModel) = m.feedforward
get_service_name(m::ServiceModel) = m.service_name
get_use_slacks(m::ServiceModel) = m.use_slacks
get_duals(m::ServiceModel) = m.duals
get_time_series_names(m::ServiceModel) = m.time_series_names
get_attributes(m::ServiceModel) = m.attributes
get_attribute(m::ServiceModel, key::String) = get(m.attributes, key, nothing)
get_contributing_devices_map(m::ServiceModel) = m.contributing_devices_map
get_contributing_devices_map(m::ServiceModel, key) =
    get(m.contributing_devices_map, key, nothing)
get_contributing_devices(m::ServiceModel) =
    [z for x in values(m.contributing_devices_map) for z in x]
add_contributing_devices_map!(m::ServiceModel, key, value) =
    m.contributing_devices_map[key] = value

function ServiceModel(
    service_type::Type{D},
    formulation_type::Type{B};
    use_slacks = false,
    feedforward = nothing,
    duals = Vector{DataType}(),
    time_series_names = initialize_timeseries_names(D, B),
    attributes = initialize_attributes(D, B),
) where {D <: PSY.Service, B <: AbstractServiceFormulation}
    if !haskey(attributes, "aggregated_service_model")
        push!(attributes, "aggregated_service_model" => true)
    end
    return ServiceModel(
        service_type,
        formulation_type,
        NO_SERVICE_NAME_PROVIDED;
        use_slacks,
        feedforward,
        duals,
        time_series_names,
        attributes,
    )
end

function populate_aggregated_service_model!(template, sys::PSY.System)
    services_template = get_service_models(template)
    for (key, service_model) in services_template
        attributes = get_attributes(service_model)
        if get(attributes, "aggregated_service_model", false)
            delete!(services_template, key)
            D = get_component_type(service_model)
            B = get_formulation(service_model)
            for service in PSY.get_components(D, sys)
                new_key = (PSY.get_name(service), Symbol(D))
                if !haskey(services_template, new_key)
                    set_service_model!(template, ServiceModel(D, B, PSY.get_name(service)))
                end
            end
        end
    end
    return
end

function _set_model!(dict::Dict, key::Tuple{String, Symbol}, model::ServiceModel)
    if haskey(dict, key)
        @info("Overwriting $(key) existing model")
    end
    dict[key] = model
    return
end

function _set_model!(
    dict::Dict,
    model::ServiceModel{D, B},
) where {D <: PSY.Service, B <: AbstractServiceFormulation}
    _set_model!(dict, (get_service_name(model), Symbol(D)), model)
    return
end
