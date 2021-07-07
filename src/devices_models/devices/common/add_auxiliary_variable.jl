"""
Add variables to the OptimizationContainer for any component.
"""
function add_variables!(
    optimization_container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::Union{AbstractDeviceFormulation, AbstractServiceFormulation},
) where {T <: AuxVariableType, U <: PSY.Component}
    add_variable!(optimization_container, T(), devices, formulation)
end

@doc raw"""
Default implementation of adding auxiliary variable to the model.
"""
function add_variable!(
    optimization_container::OptimizationContainer,
    var_type::AuxVariableType,
    devices::U,
    formulation,
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where {D <: PSY.Component}
    @assert !isempty(devices)
    time_steps = get_time_steps(optimization_container)
    add_aux_var_container!(
        optimization_container,
        var_type,
        D,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )
    return
end
