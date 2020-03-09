struct ParameterContainer
    update_ref::UpdateRef
    parameter_array::JuMP.Containers.DenseAxisArray
    multiplier_array::JuMP.Containers.DenseAxisArray
end

get_parameter_array(c::ParameterContainer) = c.parameter_array
Base.length(c::ParameterContainer) = length(c.parameter_array)
Base.size(c::ParameterContainer) = size(c.parameter_array)

const ParametersContainer = Dict{Symbol, ParameterContainer}
