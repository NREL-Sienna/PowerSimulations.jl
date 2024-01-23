function add_power_flow_data!(::OptimizationContainer, ::Nothing, ::PSY.System)
    # NO OP function
    return
end

function _add_branches_aux_variables!(
    container::OptimizationContainer,
    vars::Vector{DataType},
    branch_types::Vector{DataType},
    branch_lookup::Dict{String, Int},
)
    branch_type_map = Dict{String, DataType}(k => branch_types[v] for (k, v) in branch_lookup)
    time_steps = get_time_steps(container)
    for var_type in vars
        for D in Set(branch_types)
            branch_names = [k for (k, v) in branch_type_map if v == D]
            add_aux_variable_container!(
                container,
                var_type(),
                D,
                branch_names,
                time_steps,
            )
        end
    end
    return
end

function _add_buses_aux_variables!(
    container::OptimizationContainer,
    vars::Vector{DataType},
    bus_lookup::Dict{Int, Int},
)
    time_steps = get_time_steps(container)
    for var_type in vars
        add_aux_variable_container!(
            container,
            var_type(),
            PSY.ACBus,
            sort!(collect(keys(bus_lookup))),
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
    pf_data = PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
    container.power_flow_data = pf_data
    branch_aux_vars = [PowerFlowLineActivePower]
    _add_branches_aux_variables!(container, branch_aux_vars, PFS.get_branch_type(pf_data), PFS.get_branch_lookup(pf_data))
    return
end

function add_power_flow_data!(
    container::OptimizationContainer,
    evaluator::PFS.DCPowerFlow,
    sys::PSY.System,
)
    @info "Building PowerFlow evaluator using $(evaluator)"
    pf_data = PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
    container.power_flow_data = pf_data
    branch_aux_vars = [PowerFlowLineActivePower]
    _add_branches_aux_variables!(container, branch_aux_vars, PFS.get_branch_type(pf_data), PFS.get_branch_lookup(pf_data))
    bus_aux_vars = [PowerFlowVoltageAngle]
    _add_buses_aux_variables!(container, bus_aux_vars, PFS.get_bus_lookup(pf_data))
    return
end

function add_power_flow_data!(
    container::OptimizationContainer,
    evaluator::PFS.ACPowerFlow,
    sys::PSY.System,
)
    @info "Building PowerFlow evaluator using $(evaluator)"
    pf_data =  PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
    container.power_flow_data = pf_data
    branch_aux_vars = [PowerFlowLineActivePower, PowerFlowLineReactivePower]
    _add_branches_aux_variables!(container, branch_aux_vars, PFS.get_branch_type(pf_data), PFS.get_branch_lookup(pf_data))
    bus_aux_vars = [PowerFlowVoltageAngle, PowerFlowVoltageMagnitude]
    _add_buses_aux_variables!(container, bus_aux_vars, PFS.get_bus_lookup(pf_data))
    return
end

function make_injection_map(pf_data, container, sys)

    for var in get_variables(container)

    end

    for param in get_parameters(container)

    end

    for comp in PSY.get_componets(PSY.get_available, StaticInjection, sys)

    end
end


function update_pf_data!(pf_data, container::OptimizationContainer)

end

function solve_powerflow!(
    container::OptimizationContainer,
    system::PSY.System)
    pf_data = get_pf_data(container)
    update_pf_data!(pf_data, container)
    PFS.solve_powerflow!(pf_data)
end

function calculate_aux_variable_value!(container::OptimizationContainer,
    key,
    system::PSY.System)
    return
end
