function _add_var_container!(ps_m::CanonicalModel, var_name::Symbol, ax1, ax2)
    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, ax1, ax2)
    return
end

function _add_cons_container!(ps_m::CanonicalModel, cons_name::Symbol, ax1, ax2)
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, ax1, ax2)
    return
end
