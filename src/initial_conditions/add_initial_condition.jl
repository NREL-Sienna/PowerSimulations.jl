function _set_initial_condition!(ini_cond::Vector{InitialCondition{T, PJ.ParameterRef}}, ix::Int, val::Float64, container::OptimizationContainer) where T <: InitialConditionType
    ini_cond[ix] = add_jump_parameter(container.JuMPmodel, val)
    return
end

function _set_initial_condition!(ini_cond::Vector{InitialCondition{T, Float64}}, ix::Int, val::Float64, ::OptimizationContainer) where T <: InitialConditionType
    ini_cond[ix] = val
    return
end

function add_initial_condition!(
    container::OptimizationContainer,
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ::Type{U},
    ::D,
) where {
    T <: PSY.Component,
    U <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    D <: InitialConditionType,
}
    add_initial_condition_container!(container, D(), T, devices)
    for (ix, device) in enumerate(devices)
        val = get_initial_condition_value(D(), device, U())
        set_initial_condition!(ini_cond, ix, val, container)
    end
end
