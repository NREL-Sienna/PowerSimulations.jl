abstract type AbstractServiceFormulation end

mutable struct ServiceModel{D <: PSY.Service,
                            B <: AbstractServiceFormulation}
    service::Type{D}
    formulation::Type{B}
end



function construct_service!(ps_m::CanonicalModel,
                           service_model::ServiceModel,
                           system_formulation::Type{S},
                           sys::PSY.System,
                           time_steps::UnitRange{Int64};
                           kwargs...) where {S <: PM.AbstractPowerFormulation}

    construct_service!(ps_m,
                      service_model.service,
                      service_model.formulation,
                      system_formulation,
                      sys,
                      time_steps;
                      kwargs...)

    return

end
