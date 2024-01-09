function add_power_flow_data!(::OptimizationContainer, ::Nothing, ::PSY.System)
    # NO OP function
end

function _add_branches_aux_variables!(
    container::OptimizationContainer,
    vars::Vector{DataType},
    branch_types::Vector{DataType},
    branch_names::Vector{String},
)
    time_steps = get_time_steps(container)
    for var_type in vars
        for D in Set(branch_types)
            add_aux_variable_container!(
                container,
                var_type,
                D,
                branch_names[branch_types == D],
                time_steps,
            )
        end
    end
    return
end

function _add_buses_aux_variables!(
    container::OptimizationContainer,
    vars::Vector{DataType},
    bus_names::Vector{String},
)
    time_steps = get_time_steps(container)
    for var_type in vars
        add_aux_variable_container!(
            container,
            var_type,
            D,
            bus_names,
            time_steps,
        )
    end
    return
end

function add_power_flow_data!(
    container::OptimizationContainer,
    evaluator::T,
    sys::PSY.System,
) where {T <: Union{PFS.PTDFDCPowerFlow, PFS.vPTDFDCPowerFlow}}
    @info "Building PowerFlow evaluator using $(evaluator)"
    container.power_flow_data =
        PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
end

function add_power_flow_data!(
    container::OptimizationContainer,
    evaluator::PFS.DCPowerFlow,
    sys::PSY.System,
)
    @info "Building PowerFlow evaluator using $(evaluator)"
    container.power_flow_data =
        PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
end

function add_power_flow_data!(
    container::OptimizationContainer,
    evaluator::PFS.ACPowerFlow,
    sys::PSY.System,
)
    @info "Building PowerFlow evaluator using $(evaluator)"
    container.power_flow_data =
        PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
end
