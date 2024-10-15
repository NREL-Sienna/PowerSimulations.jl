function add_power_flow_data!(::OptimizationContainer, ::Nothing, ::PSY.System)
    # NO OP function
    return
end

function _add_aux_variables!(
    container::OptimizationContainer,
    component_map::Dict{Type{<:AuxVariableType}, <:Set{<:Tuple{DataType, Any}}},
)
    for (var_type, components) in pairs(component_map)
        component_types = unique(first.(components))
        for component_type in component_types
            component_names = [v for (k, v) in components if k <: component_type]
            sort!(component_names)
            add_aux_variable_container!(
                container,
                var_type(),
                component_type,
                component_names,
                get_time_steps(container),
            )
        end
    end
end

# Trait that determines what keys serve as input to each type of power flow
# Currently there is only the default; written this way so as to be easily overridable
pf_input_keys(::PFS.PowerFlowContainer) =
    [ActivePowerVariable, PowerOutput, ActivePowerTimeSeriesParameter]

# Maps the StaticInjection component type by name to the
# index in the PowerFlow data arrays going from Bus number to bus index
function _make_temp_component_bus_map(pf_data::PFS.PowerFlowData, sys::PSY.System)
    temp_component_bus_map = Dict{DataType, Dict{String, Int}}()
    available_injectors = PSY.get_components(PSY.get_available, PSY.StaticInjection, sys)
    bus_lookup = PFS.get_bus_lookup(pf_data)
    for comp in available_injectors
        comp_type = typeof(comp)
        bus_dict = get!(temp_component_bus_map, comp_type, Dict{String, Int}())
        bus_number = PSY.get_number(PSY.get_bus(comp))
        bus_dict[get_name(comp)] = bus_lookup[bus_number]
    end
    return temp_component_bus_map
end

# Creates Sets of components by type
function _make_temp_component_bus_map(::PFS.SystemPowerFlowContainer, sys::PSY.System)
    temp_component_bus_map = Dict{DataType, Set{String}}()
    # TODO `ComponentSelector` use case
    available_injectors = PSY.get_components(PSY.get_available, PSY.StaticInjection, sys)
    for comp_type in unique(typeof.(available_injectors))
        temp_component_bus_map[comp_type] =
            Set(filter(x -> typeof(x) == comp_type, available_injectors))
    end
    return temp_component_bus_map
end

function _make_injection_map!(
    pf_e_data::PowerFlowEvaluationData,
    container::OptimizationContainer,
    sys::PSY.System,
)
    pf_data = get_power_flow_data(pf_e_data)
    temp_component_bus_map = _make_temp_component_bus_map(pf_data, sys)
    injection_keys = pf_input_keys(pf_data)

    # Second map that persists to store the bus index that the variable
    # has to be added/substracted to in the power flow data dictionary
    pf_data_opt_container_map = Dict{OptimizationContainerKey, Dict{String, Int}}()
    added_injection_types = DataType[]
    for (key, array) in get_variables(container)
        if get_entry_type(key) ∉ injection_keys
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
        if get_entry_type(key) ∉ injection_keys
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
        if get_entry_type(key) ∉ injection_keys
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

# Trait that determines what branch aux vars we can get from each type of power flow
branch_aux_vars(::PFS.ACPowerFlow) = [PowerFlowLineActivePower, PowerFlowLineReactivePower]
branch_aux_vars(::PFS.DCPowerFlow) = [PowerFlowLineActivePower, PowerFlowLineReactivePower]
branch_aux_vars(::PFS.PTDFDCPowerFlow) = [PowerFlowLineActivePower]
branch_aux_vars(::PFS.vPTDFDCPowerFlow) = [PowerFlowLineActivePower]
branch_aux_vars(::PFS.PSSEExportPowerFlow) =
    [PowerFlowLineActivePower, PowerFlowLineReactivePower]

# Same for bus aux vars
bus_aux_vars(::PFS.ACPowerFlow) = [PowerFlowVoltageAngle, PowerFlowVoltageMagnitude]
bus_aux_vars(::PFS.DCPowerFlow) = [PowerFlowVoltageAngle]
bus_aux_vars(::PFS.PTDFDCPowerFlow) = Vector{DataType}[]
bus_aux_vars(::PFS.vPTDFDCPowerFlow) = Vector{DataType}[]
bus_aux_vars(::PFS.PSSEExportPowerFlow) = [PowerFlowVoltageAngle, PowerFlowVoltageMagnitude]

_get_branch_component_tuples(pfd::PFS.PowerFlowData) =
    zip(PFS.get_branch_type(pfd), keys(PFS.get_branch_lookup(pfd)))

_get_branch_component_tuples(pfd::PFS.SystemPowerFlowContainer) =
    [(typeof(c), get_name(c)) for c in get_components(Branch, get_system(pfd))]

_get_bus_component_tuples(pfd::PFS.PowerFlowData) =
    tuple.(PSY.ACBus, keys(PFS.get_bus_lookup(pfd)))  # get_bus_type returns a ACBusTypes, not the DataType we need here

_get_bus_component_tuples(pfd::PFS.SystemPowerFlowContainer) =
    [(typeof(c), PSY.get_number(c)) for c in get_components(Bus, get_system(pfd))]

function add_power_flow_data!(
    container::OptimizationContainer,
    evaluators::Vector{PFS.PowerFlowEvaluationModel},
    sys::PSY.System,
)
    container.power_flow_evaluation_data = Vector{PowerFlowEvaluationData}()
    sizehint!(container.power_flow_evaluation_data, length(evaluators))
    # For each output key, what components are we working with?
    branch_aux_var_components =
        Dict{Type{<:AuxVariableType}, Set{Tuple{<:DataType, String}}}()
    bus_aux_var_components = Dict{Type{<:AuxVariableType}, Set{Tuple{<:DataType, <:Int}}}()
    for evaluator in evaluators
        @info "Building PowerFlow evaluator using $(evaluator)"
        pf_data = PFS.make_power_flow_container(evaluator, sys;
            time_steps = length(get_time_steps(container)))
        pf_e_data = PowerFlowEvaluationData(pf_data)
        my_branch_aux_vars = branch_aux_vars(evaluator)
        my_bus_aux_vars = bus_aux_vars(evaluator)

        my_branch_components = _get_branch_component_tuples(pf_data)
        for branch_aux_var in my_branch_aux_vars
            to_add_to = get!(
                branch_aux_var_components,
                branch_aux_var,
                Set{Tuple{<:DataType, String}}(),
            )
            push!.(Ref(to_add_to), my_branch_components)
        end

        my_bus_components = _get_bus_component_tuples(pf_data)
        for bus_aux_var in my_bus_aux_vars
            to_add_to =
                get!(bus_aux_var_components, bus_aux_var, Set{Tuple{<:DataType, <:Int}}())
            push!.(Ref(to_add_to), my_bus_components)
        end
        _make_injection_map!(pf_e_data, container, sys)
        push!(container.power_flow_evaluation_data, pf_e_data)
    end

    _add_aux_variables!(container, branch_aux_var_components)
    _add_aux_variables!(container, bus_aux_var_components)
end

function _write_value_to_pf_data!(
    pf_data::PFS.PowerFlowData,
    container::OptimizationContainer,
    key::OptimizationContainerKey,
    bus_index_map)
    result = lookup_value(container, key)
    for (device_name, index) in bus_index_map
        injection_values = result[device_name, :]
        for t in axes(result)[2]
            pf_data.bus_activepower_injection[index, t] += jump_value(injection_values[t])
        end
    end
    return
end

function update_pf_data!(
    pf_e_data::PowerFlowEvaluationData{<:PFS.PowerFlowData},
    container::OptimizationContainer,
)
    pf_data = get_power_flow_data(pf_e_data)
    PFS.clear_injection_data!(pf_data)
    key_map = get_injection_key_map(pf_e_data)
    for (key, bus_index_map) in key_map
        _write_value_to_pf_data!(pf_data, container, key, bus_index_map)
    end
    return
end

function update_pf_system!(sys::PSY.System, container::OptimizationContainer, key_map)
    TIME = 1  # TODO figure out how to handle multiple time periods here
    for (key, bus_index_map) in key_map
        result = lookup_value(container, key)
        for (device_name, _) in bus_index_map
            injection_values = result[device_name, :]
            comp = PSY.get_component(get_component_type(key), sys, device_name)
            comp.active_power = jump_value(injection_values[TIME])
        end
    end
end

function update_pf_data!(
    pf_e_data::PowerFlowEvaluationData{<:PFS.SystemPowerFlowContainer},
    container::OptimizationContainer,
)
    pf_data = get_power_flow_data(pf_e_data)
    key_map = get_injection_key_map(pf_e_data)
    update_pf_system!(PFS.get_system(pf_data), container, key_map)
    return
end

"Fetch the most recently solved `PowerFlowEvaluationData`"
function latest_solved_power_flow_evaluation_data(container::OptimizationContainer)
    datas = get_power_flow_evaluation_data(container)
    return datas[findlast(x -> x.is_solved, datas)]
end

function solve_powerflow!(
    pf_e_data::PowerFlowEvaluationData,
    container::OptimizationContainer)
    update_pf_data!(pf_e_data, container)
    PFS.solve_powerflow!(get_power_flow_data(pf_e_data))
    pf_e_data.is_solved = true
    return
end

function calculate_aux_variable_value!(container::OptimizationContainer,
    key,
    system::PSY.System)
    # TODO read data back from the power flow
    return
end
