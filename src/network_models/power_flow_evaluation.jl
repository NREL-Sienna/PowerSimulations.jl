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
    temp_component_bus_map = Dict{DataType, Dict{String, String}}()
    # TODO `ComponentSelector` use case
    available_injectors =
        collect(PSY.get_components(PSY.get_available, PSY.StaticInjection, sys))
    for comp_type in unique(typeof.(available_injectors))
        temp_component_bus_map[comp_type] =
            Dict(
                PSY.get_name(c) => PSY.get_name(c) for
                c in available_injectors if c isa comp_type
            )
    end
    return temp_component_bus_map
end

function _make_pf_input_map!(
    pf_e_data::PowerFlowEvaluationData,
    container::OptimizationContainer,
    sys::PSY.System,
)
    pf_data = get_power_flow_data(pf_e_data)
    temp_component_bus_map = _make_temp_component_bus_map(pf_data, sys)
    map_type = valtype(temp_component_bus_map)  # Dict{String, Int} for PowerFlowData, Dict{String, String} for SystemPowerFlowContainer
    injection_keys = pf_input_keys(pf_data)

    # Second map that persists to store the bus index that the variable
    # has to be added/substracted to in the power flow data dictionary
    pf_data_opt_container_map = Dict{OptimizationContainerKey, map_type}()
    added_injection_types = DataType[]
    for (key, val) in Iterators.flatten([
        get_variables(container),
        get_aux_variables(container),
        get_parameters(container),
    ])
        # Skip irrelevant keys
        (get_entry_type(key) in injection_keys) || continue

        comp_type = get_component_type(key)
        # Skip types that have already been handled (prefer variable over aux variable, aux variable over parameter)
        (comp_type in added_injection_types) && continue
        push!(added_injection_types, comp_type)

        name_bus_ix_map = map_type()
        # Maybe this should be rewritten as multiple dispatch but it should not be rewritten as a copypasted loop
        comp_names =
            (key isa ParameterKey) ? get_component_names(get_attributes(val)) : axes(val)[1]
        for comp_name in comp_names
            name_bus_ix_map[comp_name] = temp_component_bus_map[comp_type][comp_name]
        end
        pf_data_opt_container_map[key] = name_bus_ix_map
    end

    pf_e_data.input_key_map = pf_data_opt_container_map
    return
end

# Trait that determines what branch aux vars we can get from each PowerFlowContainer
branch_aux_vars(::PFS.ACPowerFlowData) =
    [PowerFlowLineActivePower, PowerFlowLineReactivePower]
branch_aux_vars(::PFS.ABAPowerFlowData) = [PowerFlowLineActivePower]
branch_aux_vars(::PFS.PTDFPowerFlowData) = [PowerFlowLineActivePower]
branch_aux_vars(::PFS.vPTDFPowerFlowData) = [PowerFlowLineActivePower]
branch_aux_vars(::PFS.PSSEExporter) = DataType[]

# Same for bus aux vars
bus_aux_vars(::PFS.ACPowerFlowData) = [PowerFlowVoltageAngle, PowerFlowVoltageMagnitude]
bus_aux_vars(::PFS.ABAPowerFlowData) = [PowerFlowVoltageAngle]
bus_aux_vars(::PFS.PTDFPowerFlowData) = DataType[]
bus_aux_vars(::PFS.vPTDFPowerFlowData) = DataType[]
bus_aux_vars(::PFS.PSSEExporter) = DataType[]

_get_branch_component_tuples(pfd::PFS.PowerFlowData) =
    zip(PFS.get_branch_type(pfd), keys(PFS.get_branch_lookup(pfd)))

_get_branch_component_tuples(pfd::PFS.SystemPowerFlowContainer) =
    [(typeof(c), get_name(c)) for c in PSY.get_components(PSY.Branch, PFS.get_system(pfd))]

_get_bus_component_tuples(pfd::PFS.PowerFlowData) =
    tuple.(PSY.ACBus, keys(PFS.get_bus_lookup(pfd)))  # get_bus_type returns a ACBusTypes, not the DataType we need here

_get_bus_component_tuples(pfd::PFS.SystemPowerFlowContainer) =
    [
        (typeof(c), PSY.get_number(c)) for
        c in PSY.get_components(PSY.Bus, PFS.get_system(pfd))
    ]

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
        my_branch_aux_vars = branch_aux_vars(pf_data)
        my_bus_aux_vars = bus_aux_vars(pf_data)

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
        _make_pf_input_map!(pf_e_data, container, sys)
        push!(container.power_flow_evaluation_data, pf_e_data)
    end

    _add_aux_variables!(container, branch_aux_var_components)
    _add_aux_variables!(container, bus_aux_var_components)
end

asdf = 1
function _write_value_to_pf_data!(
    pf_data::PFS.PowerFlowData,
    container::OptimizationContainer,
    key::OptimizationContainerKey,
    bus_index_map)
    PowerSimulations.asdf = container
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
    key_map = get_input_key_map(pf_e_data)
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
    key_map = get_input_key_map(pf_e_data)
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

# Currently nothing to write back to the optimization container from a PSSEExporter
calculate_aux_variable_value!(::OptimizationContainer,
    ::AuxVarKey{T, <:Any} where {T <: PowerFlowAuxVariableType},
    ::PSY.System, ::PowerFlowEvaluationData{PFS.PSSEExporter}) = nothing

_get_pf_result(::Type{PowerFlowVoltageAngle}, pf_data::PFS.PowerFlowData) =
    PFS.get_bus_angles(pf_data)
_get_pf_result(::Type{PowerFlowVoltageMagnitude}, pf_data::PFS.PowerFlowData) =
    PFS.get_bus_magnitude(pf_data)
_get_pf_result(::Type{PowerFlowLineActivePower}, pf_data::PFS.PowerFlowData) =
    PFS.get_branch_flow_values(pf_data)
# TODO implement method for PowerFlowLineReactivePower -- I don't think we have a PowerFlowData field for this?
# _fetch_pf_result(pf_data::PFS.PowerFlowData, ::Type{PowerFlowLineActivePower}) = ...

_get_pf_lookup(::Type{<:PSY.Bus}, pf_data::PFS.PowerFlowData) = PFS.get_bus_lookup(pf_data)
_get_pf_lookup(::Type{<:PSY.Branch}, pf_data::PFS.PowerFlowData) =
    PFS.get_branch_lookup(pf_data)

function calculate_aux_variable_value!(container::OptimizationContainer,
    key::AuxVarKey{T, U},
    system::PSY.System, pf_e_data::PowerFlowEvaluationData{<:PFS.PowerFlowData},
) where {T <: PowerFlowAuxVariableType, U}
    @debug "Updating $key from PowerFlowData"
    pf_data = get_power_flow_data(pf_e_data)
    src = _get_pf_result(T, pf_data)
    lookup = _get_pf_lookup(U, pf_data)
    dest = get_aux_variable(container, key)
    for component_id in axes(dest, 1)  # these are bus numbers or branch names
        dest[component_id, :] = src[lookup[component_id], :]
    end
    return
end

function calculate_aux_variable_value!(container::OptimizationContainer,
    key::AuxVarKey{T, <:Any} where {T <: PowerFlowAuxVariableType},
    system::PSY.System)
    pf_e_data = latest_solved_power_flow_evaluation_data(container)
    pf_data = get_power_flow_data(pf_e_data)
    # Skip the aux vars that the current power flow isn't meant to update
    (key in branch_aux_vars(pf_data) || key in bus_aux_vars(pf_data)) && return
    calculate_aux_variable_value!(container, key, system, pf_e_data)
end
