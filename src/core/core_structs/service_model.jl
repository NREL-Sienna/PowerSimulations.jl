abstract type AbstractServiceForm end

mutable struct ServiceModel{D<:PSY.Service,
                            B<:AbstractServiceForm}
    service::Type{D}
    formulation::Type{B}
end



function construct_service!(canonical_model::CanonicalModel,
                           service_model::ServiceModel,
                           system_formulation::Type{S},
                           sys::PSY.System;
                           kwargs...) where {S<:PM.AbstractPowerFormulation}

    construct_service!(canonical_model,
                      service_model.service,
                      service_model.formulation,
                      system_formulation,
                      sys;
                      kwargs...)

    return

end
