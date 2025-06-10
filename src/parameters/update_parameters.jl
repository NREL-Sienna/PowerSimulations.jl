"""
Update parameter function an OperationModel
"""
function update_parameter_values!(
    model::OperationModel,
    key::ParameterKey{T, U},
    simulation_state::SimulationState,
) where {T <: ParameterType, U <: PSY.Component}
    # Enable again for detailed debugging
    # TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
    optimization_container = get_optimization_container(model)
    input = get_decision_states(simulation_state)
    update_container_parameter_values!(optimization_container, model, key, input)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    IS.@record :execution ParameterUpdateEvent(
        T,
        U,
        parameter_attributes,
        get_current_timestamp(model),
        get_name(model),
    )
    #end
    return
end

function _fix_parameter_value!(
    container::OptimizationContainer,
    parameter_array::DenseAxisArray{Float64, 2},
    parameter_attributes::VariableValueAttributes,
)
    affected_variable_keys = parameter_attributes.affected_keys
    @assert !isempty(affected_variable_keys)
    for var_key in affected_variable_keys
        variable = get_variable(container, var_key)
        component_names, time = axes(parameter_array)
        for t in time, name in component_names
            JuMP.fix(variable[name, t], parameter_array[name, t]; force = true)
        end
    end
    return
end

function update_parameter_values!(
    model::OperationModel,
    key::ParameterKey{FixValueParameter, T},
    simulation_state::SimulationState,
) where {T <: PSY.Service}
    # Enable again for detailed debugging
    # TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
    optimization_container = get_optimization_container(model)
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = get_parameter_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    service = PSY.get_component(T, get_system(model), key.meta)
    @assert service !== nothing
    input = get_decision_states(simulation_state)
    _update_parameter_values!(
        parameter_array,
        FixValueParameter(),
        parameter_attributes,
        service,
        model,
        input,
    )
    _fix_parameter_value!(optimization_container, parameter_array, parameter_attributes)
    IS.@record :execution ParameterUpdateEvent(
        FixValueParameter,
        T,
        parameter_attributes,
        get_current_timestamp(model),
        get_name(model),
    )
    #end
    return
end
