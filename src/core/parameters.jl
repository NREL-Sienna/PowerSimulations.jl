struct ParameterContainer
    update_ref::UpdateRef
    array::JuMP.Containers.DenseAxisArray
end

get_parameter_array(c::ParameterContainer) = c.array
Base.length(c::ParameterContainer) = length(c.array)
Base.size(c::ParameterContainer) = size(c.array)

const ParametersContainer = Dict{Symbol, ParameterContainer}
