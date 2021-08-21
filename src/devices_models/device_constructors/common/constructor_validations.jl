function validate_available_devices(
    device::DeviceModel{T, U},
    system,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    devices = get_available_components(T, system)
    if isempty(devices)
        @warn "The data doesn't include devices of type $(T), consider changing the device models" _group =
            :ConstructGroup

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
        @warn "The data doesn't include services of type $(service), consider changing the service models" _group =
            :ConstructGroup
        return false
    end

    services_mapping = PSY.get_contributing_device_mapping(sys)
    for s in services_
        contributing_devices_ =
            services_mapping[(type = S, name = PSY.get_name(s))].contributing_devices
        contributing_devices =
            [d for d in contributing_devices_ if typeof(d) ∉ incompatible_device_types]
        if isempty(contributing_devices)
            @warn "The contributing devices for service $(PSY.get_name(s)) is empty, consider removing the service from the system" _group =
                :ConstructGroup
        else
            push!(services, s)
        end
    end
    return true
end

function validate_services!(
    service::Type{S},
    services::Vector{S},
    ::Vector{<:DataType},
    sys::PSY.System,
) where {S <: PSY.StaticReserveGroup}
    services_ = PSY.get_components(S, sys)
    if isempty(services_)
        @warn "The data doesn't include services of type $(service), consider changing the service models" _group =
            :ConstructGroup
        return false
    end

    for s in services_
        contributing_services = PSY.get_contributing_services(s)
        if isempty(contributing_services)
            @warn "The contributing services for group service $(PSY.get_name(service)) is empty, consider removing the group service from the system" _group =
                :ConstructGroup
        else
            push!(services, s)
        end
    end
    return !isempty(services)
end
