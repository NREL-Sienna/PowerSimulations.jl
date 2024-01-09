function add_power_flow_data!(container::OptimizationContainer, evaluator::Nothing)
# NO OP function
end

add_aux_variable_container!(
    container,
    var_type,
    D,
    [PSY.get_name(d) for d in devices],
    time_steps,
)

function add_power_flow_data!(container::OptimizationContainer, evaluator::T) where T <: Union{PFS.PTDFDCPowerFlow, PFS.vPTDFDCPowerFlow}
    @info "Building PowerFlow evaluator using $(evaluator)"
    container.power_flow_data = PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
end

function add_power_flow_data!(container::OptimizationContainer, evaluator::PFS.DCPowerFlow())
    @info "Building PowerFlow evaluator using $(evaluator)"
    container.power_flow_data = PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
end


function add_power_flow_data!(container::OptimizationContainer, evaluator::PFS.ACPowerFlow())
    @info "Building PowerFlow evaluator using $(evaluator)"
    container.power_flow_data = PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
end
