function validate_available_devices(device::Type{D}, devices) where {D <: PSY.Device}
    if isempty(devices)
        @warn("The data doesn't include devices of type $(device), consider changing the device models")
        return false
    end
    return true
end

function validate_services!(
    service::Type{S},
    services::Vector{S},
    incompatible_device_types::Vector{<:DataType},
    sys::PSY.System,
) where {S <: PSY.Service}
    services_ = PSY.get_components(S, sys)
    if isempty(services_)
        @warn("The data doesn't include services of type $(service), consider changing the service models")
        return false
    end

    services_mapping = PSY.get_contributing_device_mapping(sys)
    for s in services_
        contributing_devices_ =
            services_mapping[(type = S, name = PSY.get_name(s))].contributing_devices
        contributing_devices =
            [d for d in contributing_devices_ if typeof(d) ∉ incompatible_device_types]
        if isempty(contributing_devices)
            @warn("The contributing devices for service $(PSY.get_name(service)) is empty, consider removing the service from the system")
        else
            push!(services, s)
        end
    end
    return true
end
