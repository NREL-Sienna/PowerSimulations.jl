abstract type AbstractServiceFormulation end

mutable struct ServiceModel{D <: PSY.Service, B <: AbstractServiceFormulation}
    service_type::Type{D}
    formulation::Type{B}
end
