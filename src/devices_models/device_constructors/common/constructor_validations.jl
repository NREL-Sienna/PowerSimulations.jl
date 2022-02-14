function validate_available_devices(
    device::DeviceModel{T, U},
    system,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    devices = get_available_components(T, system)
    if isempty(devices)
        @info "The data doesn't include devices of type $(T), consider changing the device models" _group =
            LOG_GROUP_MODELS_VALIDATION
        return false
    end
    PSY.check_components(system, devices)
    return true
end

function validate_service!(
    model::ServiceModel{S, <:AbstractServiceFormulation},
    incompatible_device_types::Set{<:DataType},
    sys::PSY.System,
) where {S <: PSY.Service}
    service = PSY.get_component(S, sys, get_service_name(model))
    if service === nothing
        @info "The data doesn't include services of type $(S) and name $(get_service_name(model)), consider changing the service models" _group =
            LOG_GROUP_MODELS_VALIDATION
        return false
    end

    PSY.check_components(sys, service)
    services_mapping = PSY.get_contributing_device_mapping(sys)

    contributing_devices_ =
        services_mapping[(type=S, name=PSY.get_name(service))].contributing_devices
    contributing_devices = [
        d for d in contributing_devices_ if
        typeof(d) ∉ incompatible_device_types && PSY.get_available(d)
    ]
    if isempty(contributing_devices)
        @warn "The contributing devices for service $(PSY.get_name(service)) is empty, consider removing the service from the system" _group =
            LOG_GROUP_MODELS_VALIDATION
        return false
    end

    PSY.check_components(sys, contributing_devices)
    return true
end

function validate_services!(
    model::ServiceModel{S, <:AbstractServiceFormulation},
    ::Vector{<:DataType},
    sys::PSY.System,
) where {S <: PSY.StaticReserveGroup}
    service = PSY.get_component(S, sys, get_service_name(model))
    if service === nothing
        @info "The data doesn't include services of type $(S) and name $(get_service_name(model)), consider changing the service models" _group =
            LOG_GROUP_MODELS_VALIDATION
        return false
    end

    PSY.check_components(sys, service)
    contributing_services = PSY.get_contributing_services(s)
    if isempty(contributing_services)
        @warn "The contributing services for group service $(PSY.get_name(service)) is empty, consider removing the group service from the system" _group =
            LOG_GROUP_MODELS_VALIDATION
        return false
    end

    PSY.check_components(sys, contributing_devices)
    return true
end
