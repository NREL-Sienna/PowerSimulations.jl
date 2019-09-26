function _add_var_container!(canonical_model::CanonicalModel, var_name::Symbol, ax1, ax2)
    canonical_model.variables[var_name] = _container_spec(canonical_model.JuMPmodel, ax1, ax2)
    return
end

function _add_cons_container!(canonical_model::CanonicalModel, cons_name::Symbol, ax1, ax2)
    canonical_model.constraints[cons_name] = JuMPConstraintArray(undef, ax1, ax2)
    return
end

function _add_param_container!(canonical_model::CanonicalModel, param_reference::UpdateRef, axs...)
    canonical_model.parameters[param_reference] = JuMPParamArray(undef, axs...)
    return
end

function _middle_rename(original::Symbol, split_char::String, addition::String)

    parts = split(String(original),split_char)

    return Symbol(parts[1],"_",addition,"_",parts[2])

end

function _remove_underscore(original::Symbol)

    if !occursin("_", String(original))
        return original
    end

    parts = split(String(original),"_")

    return parts[1]
end

function remove_char(s::String, char::String)
    return replace(s, Regex("[$char]") => "")
end
