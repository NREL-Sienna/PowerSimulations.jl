""" Returns the correct container spec for the selected type of JuMP Model"""
function _container_spec(m::M, ax...) where M<:JuMP.AbstractModel
    return JuMP.Containers.DenseAxisArray{JuMP.variable_type(m)}(undef, ax...)
end

function _add_var_container!(canonical::CanonicalModel, var_name::Symbol, ax1, ax2)
    canonical.variables[var_name] = _container_spec(canonical.JuMPmodel, ax1, ax2)
    return canonical.variables[var_name]
end

function _add_cons_container!(canonical::CanonicalModel, cons_name::Symbol, ax1, ax2)
    canonical.constraints[cons_name] = JuMPConstraintArray(undef, ax1, ax2)
    return canonical.constraints[cons_name]
end

function _add_param_container!(canonical::CanonicalModel, param_reference::UpdateRef, axs...)
    canonical.parameters[param_reference] = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, axs...)
    return canonical.parameters[param_reference]
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

"Replaces the string in `char` with the string`replacement`"
function replace_chars(s::String, char::String, replacement::String)
    return replace(s, Regex("[$char]") => replacement)
end

"Removes the string `char` from the original string"
function remove_chars(s::String, char::String)
    return replace_chars(s::String, char::String, "")
end
