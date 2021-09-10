function _set_initial_condition!(ini_cond::Vector{InitialCondition{T, PJ.ParameterRef}}, ix::Int, val::Float64, container::OptimizationContainer)
    ini_cond[ix] = add_jump_parameter(container.JuMPmodel, val)
    return
end

function _set_initial_condition!(ini_cond::Vector{InitialCondition{T, Float64}}, ix::Int, val::Float64, ::OptimizationContainer)
    ini_cond[ix] = val
    return
end

function add_initial_condition!(
    container::OptimizationContainer,
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ::D,
    ::Type{U},
) where {
    T <: PSY.Component,
    U <: InitialConditionType,
    D <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
}
    add_initial_condition_container!(container, U(), T, devices)
    for (ix, device) in enumerate(devices)
        val = get_initial_condition_value(U(), T, device, D())
        set_initial_condition!(ini_cond, ix, val, container)
    end
end
