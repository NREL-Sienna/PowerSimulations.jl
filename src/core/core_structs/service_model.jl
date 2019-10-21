abstract type AbstractServiceFormulation end

mutable struct ServiceModel{D<:PSY.Service,
                            B<:AbstractServiceFormulation}
    service::Type{D}
    formulation::Type{B}
end



function construct_service!(canonical::CanonicalModel,
                           service_model::ServiceModel,
                           system_formulation::Type{S},
                           sys::PSY.System;
                           kwargs...) where {S<:PM.AbstractPowerModel}

    construct_service!(canonical,
                      service_model.service,
                      service_model.formulation,
                      system_formulation,
                      sys;
                      kwargs...)

    return

end
