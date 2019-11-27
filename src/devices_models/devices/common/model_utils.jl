""" Returns the correct container spec for the selected type of JuMP Model"""
function _container_spec(m::M, axs...) where M<:JuMP.AbstractModel
    return JuMP.Containers.DenseAxisArray{JuMP.variable_type(m)}(undef, axs...)
end

function add_var_container!(psi_container::PSIContainer, var_name::Symbol, axs...)
    psi_container.variables[var_name] = _container_spec(psi_container.JuMPmodel, axs...)
    return psi_container.variables[var_name]
end

function add_cons_container!(psi_container::PSIContainer, cons_name::Symbol, axs...)
    psi_container.constraints[cons_name] = JuMPConstraintArray(undef, axs...)
    return psi_container.constraints[cons_name]
end

function _add_param_container!(psi_container::PSIContainer, param_reference::UpdateRef, axs...)
    psi_container.parameters[param_reference] = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, axs...)
    return psi_container.parameters[param_reference]
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
