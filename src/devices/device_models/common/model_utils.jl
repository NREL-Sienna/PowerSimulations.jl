function _add_var_container!(ps_m::CanonicalModel, var_name::Symbol, ax1, ax2)
    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, ax1, ax2)
    return
end

function _add_cons_container!(ps_m::CanonicalModel, cons_name::Symbol, ax1, ax2)
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, ax1, ax2)
    return
end

function _add_param_container!(ps_m::CanonicalModel, param_name::Symbol, axs...)
    ps_m.parameters[param_name] = JuMPParamArray(undef, axs...)
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