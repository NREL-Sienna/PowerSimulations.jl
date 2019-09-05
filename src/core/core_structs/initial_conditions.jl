# The struct InitialCondition is located in Line 10 of file canonical_model.
function InitialCondition(canonical::CanonicalModel,
                            device::T,
                            access_ref::Symbol,
                            value::Float64) where T <: PSY.Device

    if model_has_parameters(canonical)
        return InitialCondition(device,
                                UpdateRef{PJ.ParameterRef}(access_ref),
                                PJ.add_parameter(canonical.JuMPmodel, value))
    else
        !hasfield(T, access_ref) && error("Device of of type $(T) doesn't contain
                                            the field $(access_ref)")
        return InitialCondition(device,
                                UpdateRef{T}(access_ref),
                                value)
    end

end

function value(p::InitialCondition{Float64})
    return p.value
end

function value(p::InitialCondition{PJ.ParameterRef})
    return PJ.value(p.value)
end

get_condition(ic::InitialCondition) = ic.value

function  get_ini_cond(canonical_model::CanonicalModel, name::Symbol)
    return get(canonical_model.initial_conditions, name, Vector{InitialCondition}())
end

device_name(ini_cond::InitialCondition) = PSY.get_name(ini_cond.device)
