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
    branch_type_map =
        Dict{String, DataType}(k => branch_types[v] for (k, v) in branch_lookup)
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

const ACTIVE_POWER_INJECTION_KEYS = [
    ActivePowerVariable
    PowerOutput
    ActivePowerTimeSeriesParameter
]

function _make_injection_map!(container::OptimizationContainer, sys::PSY.System)
    pf_e_data = get_power_flow_evaluation_data(container)
    pf_data = get_power_flow_data(pf_e_data)
    # Maps the StaticInjection component type by name to the
    # index in the PowerFlow data arrays going from Bus number to bus index
    temp_component_bus_map = Dict{DataType, Dict{String, Int}}()
    available_injectors = PSY.get_components(PSY.get_available, PSY.StaticInjection, sys)
    sizehint!(temp_component_bus_map, length(available_injectors))
    bus_lookup = PFS.get_bus_lookup(pf_data)
    for comp in available_injectors
        comp_type = typeof(comp)
        bus_dict = get!(temp_component_bus_map, comp_type, Dict{String, Int}())
        bus_number = PSY.get_number(PSY.get_bus(comp))
        bus_dict[get_name(comp)] = bus_lookup[bus_number]
    end

    # Second map that persists to store the bus index that the variable
    # has to be added/substracted to in the power flow data dictionary
    pf_data_opt_container_map = Dict{OptimizationContainerKey, Dict{String, Int}}()
    added_injection_types = DataType[]
    for (key, array) in get_variables(container)
        if get_entry_type(key) ∉ ACTIVE_POWER_INJECTION_KEYS
            continue
        end

        name_bus_ix_map = Dict{String, Int}()
        comp_type = get_component_type(key)
        push!(added_injection_types, comp_type)
        for n in axes(array)[1]
            name_bus_ix_map[n] = temp_component_bus_map[comp_type][n]
        end

        pf_data_opt_container_map[key] = name_bus_ix_map
    end

    for (key, array) in get_aux_variables(container)
        if get_entry_type(key) ∉ ACTIVE_POWER_INJECTION_KEYS
            continue
        end
        # Skip aux variable if the device was added as a variable
        if comp_type ∈ added_injection_types
            continue
        end
        name_bus_ix_map = Dict{String, Int}()
        comp_type = get_component_type(key)
        push!(added_injection_types, comp_type)
        for n in axes(array)[1]
            name_bus_ix_map[n] = temp_component_bus_map[comp_type][n]
        end

        pf_data_opt_container_map[key] = name_bus_ix_map
    end

    for (key, param_container) in get_parameters(container)
        if get_entry_type(key) ∉ ACTIVE_POWER_INJECTION_KEYS
            continue
        end
        comp_type = get_component_type(key)
        # Skip parameter if the device was added as a variable
        if comp_type ∈ added_injection_types
            continue
        end
        param_attributes = get_attributes(param_container)
        name_bus_ix_map = Dict{String, Int}()
        for n in get_component_names(param_attributes)
            name_bus_ix_map[n] = temp_component_bus_map[comp_type][n]
        end
        pf_data_opt_container_map[key] = name_bus_ix_map
    end

    pf_e_data.injection_key_map = pf_data_opt_container_map
    return
end

function add_power_flow_data!(
    container::OptimizationContainer,
    evaluator::T,
    sys::PSY.System,
) where {T <: Union{PFS.PTDFDCPowerFlow, PFS.vPTDFDCPowerFlow}}
    @info "Building PowerFlow evaluator using $(evaluator)"
    pf_data =
        PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
    container.power_flow_evaluation_data = PowerFlowEvaluationData(pf_data)
    branch_aux_vars = [PowerFlowLineActivePower]
    _add_branches_aux_variables!(
        container,
        branch_aux_vars,
        PFS.get_branch_type(pf_data),
        PFS.get_branch_lookup(pf_data),
    )
    _make_injection_map!(container, sys)
    return
end

function add_power_flow_data!(
    container::OptimizationContainer,
    evaluator::PFS.DCPowerFlow,
    sys::PSY.System,
)
    @info "Building PowerFlow evaluator using $(evaluator)"
    pf_data =
        PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
    container.power_flow_evaluation_data = PowerFlowEvaluationData(pf_data)
    branch_aux_vars = [PowerFlowLineActivePower]
    _add_branches_aux_variables!(
        container,
        branch_aux_vars,
        PFS.get_branch_type(pf_data),
        PFS.get_branch_lookup(pf_data),
    )
    bus_aux_vars = [PowerFlowVoltageAngle]
    _add_buses_aux_variables!(container, bus_aux_vars, PFS.get_bus_lookup(pf_data))
    _make_injection_map!(container, sys)
    return
end

function add_power_flow_data!(
    container::OptimizationContainer,
    evaluator::PFS.ACPowerFlow,
    sys::PSY.System,
)
    @info "Building PowerFlow evaluator using $(evaluator)"
    pf_data =
        PFS.PowerFlowData(evaluator, sys; time_steps = length(get_time_steps(container)))
    container.power_flow_evaluation_data = PowerFlowEvaluationData(pf_data)
    branch_aux_vars = [PowerFlowLineActivePower, PowerFlowLineReactivePower]
    _add_branches_aux_variables!(
        container,
        branch_aux_vars,
        PFS.get_branch_type(pf_data),
        PFS.get_branch_lookup(pf_data),
    )
    bus_aux_vars = [PowerFlowVoltageAngle, PowerFlowVoltageMagnitude]
    _add_buses_aux_variables!(container, bus_aux_vars, PFS.get_bus_lookup(pf_data))
    _make_injection_map!(container, sys)
    return
end

function _write_value_to_pf_data!(
    pf_data::PFS.PowerFlowData,
    container::OptimizationContainer,
    key::AuxVariableKey{PowerOutput, T},
    bus_index_map) where {T <: PSY.ThermalGen}

    result = get_variable(container, key)
    for (device_name, index) in bus_index_map
        injection_values = result[device_name, :]
        for t in axes(result)[2]
            pf_data[index, t] = jump_value(injection_values[t])
        end
    end
    return
end

function _write_value_to_pf_data!(
    pf_data::PFS.PowerFlowData,
    container::OptimizationContainer,
    key::VariableKey{ParameterKey, T},
    bus_index_map) where {T <: PSY.Generator}

    result = get_variable(container, key)
    for (device_name, index) in bus_index_map
        injection_values = result[device_name, :]
        for t in axes(result)[2]
            pf_data[index, t] = jump_value(injection_values[t])
        end
    end
    return
end

function _write_value_to_pf_data!(
    pf_data::PFS.PowerFlowData,
    container::OptimizationContainer,
    key::VariableKey{ActivePowerVariable, T},
    bus_index_map) where {T <: PSY.StaticInjection}

    result = get_variable(container, key)
    for (device_name, index) in bus_index_map
        injection_values = result[device_name, :]
        for t in axes(result)[2]
            pf_data[index, t] = jump_value(injection_values[t])
        end
    end
    return
end

function update_pf_data!(pf_e_data, container::OptimizationContainer)
    pf_data = get_power_flow_data(pf_e_data)
    PFS.clear_injection_data!(pf_data)
    key_map = get_injection_key_map(container)
    for (key, bus_index_map) in key_map
        _write_value_to_pf_data!(pf_data, container, key, bus_index_map)
    end
    return
end

function solve_power_flow!(
    container::OptimizationContainer,
    system::PSY.System)
    pf_data = get_pf_data(container)
    update_pf_data!(pf_data, container)
    PFS.solve_power_flow!(pf_data)
end

function calculate_aux_variable_value!(container::OptimizationContainer,
    key,
    system::PSY.System)
    return
end
