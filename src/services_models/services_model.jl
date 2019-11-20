abstract type AbstractServiceFormulation end

mutable struct ServiceModel{D<:PSY.Service,
                            B<:AbstractServiceFormulation}
    service_type::Type{D}
    formulation::Type{B}
end

struct ServiceExpressionKey
    name::String
    device_type::Type{<:PSY.Device}
end
