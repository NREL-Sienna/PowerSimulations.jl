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

# Trait that determines what keys serve as input to each type of power flow, if they exist
pf_input_keys(::PFS.PowerFlowData) =
    [ActivePowerVariable, PowerOutput, ActivePowerTimeSeriesParameter]
pf_input_keys(::PFS.PSSEExporter) =
    [ActivePowerVariable, PowerOutput, ActivePowerTimeSeriesParameter,
        PowerFlowVoltageAngle, PowerFlowVoltageMagnitude]

# Maps the StaticInjection component type by name to the
# index in the PowerFlow data arrays going from Bus number to bus index
function _make_temp_component_map(pf_data::PFS.PowerFlowData, sys::PSY.System)
    temp_component_map = Dict{DataType, Dict{String, Int}}()
    available_injectors = PSY.get_components(PSY.get_available, PSY.StaticInjection, sys)
    bus_lookup = PFS.get_bus_lookup(pf_data)
    for comp in available_injectors
        comp_type = typeof(comp)
        bus_dict = get!(temp_component_map, comp_type, Dict{String, Int}())
        bus_number = PSY.get_number(PSY.get_bus(comp))
        bus_dict[get_name(comp)] = bus_lookup[bus_number]
    end
    return temp_component_map
end

_get_temp_component_map_lhs(comp::PSY.Component) = PSY.get_name(comp)
_get_temp_component_map_lhs(comp::PSY.Bus) = PSY.get_number(comp)

# Creates dicts of components by type
function _make_temp_component_map(::PFS.SystemPowerFlowContainer, sys::PSY.System)
    temp_component_map =
        Dict{DataType, Dict{Union{String, Int64}, String}}()
    # TODO don't hardcode the types here, handle get_available more elegantly, likely `ComponentSelector` use case
    relevant_components = vcat(
        collect.([
            PSY.get_components(PSY.get_available, PSY.StaticInjection, sys),
            PSY.get_components(Union{PSY.Bus, PSY.Branch}, sys)],
        )...,
    )
    for comp_type in unique(typeof.(relevant_components))
        # NOTE we avoid using bus numbers here because PSY.get_bus(system, number) is O(n)
        temp_component_map[comp_type] =
            Dict(
                _get_temp_component_map_lhs(c) => PSY.get_name(c) for
                c in relevant_components if c isa comp_type
            )
    end
    return temp_component_map
end

function _make_pf_input_map!(
    pf_e_data::PowerFlowEvaluationData,
    container::OptimizationContainer,
    sys::PSY.System,
)
    pf_data = get_power_flow_data(pf_e_data)
    temp_component_map = _make_temp_component_map(pf_data, sys)
    map_type = valtype(temp_component_map)  # Dict{String, Int} for PowerFlowData, Dict{Union{String, Int64}, String} for SystemPowerFlowContainer
    input_keys = pf_input_keys(pf_data)

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
        (get_entry_type(key) in input_keys) || continue

        comp_type = get_component_type(key)
        # Skip types that have already been handled (prefer variable over aux variable, aux variable over parameter)
        (comp_type in added_injection_types) && continue
        push!(added_injection_types, comp_type)

        name_bus_ix_map = map_type()
        comp_names =
            (key isa ParameterKey) ? get_component_names(get_attributes(val)) : axes(val)[1]
        for comp_name in comp_names
            name_bus_ix_map[comp_name] = temp_component_map[comp_type][comp_name]
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
        push!(container.power_flow_evaluation_data, pf_e_data)
    end

    _add_aux_variables!(container, branch_aux_var_components)
    _add_aux_variables!(container, bus_aux_var_components)

    # Make the input maps after adding aux vars so output of one power flow can be input of another
    for pf_e_data in get_power_flow_evaluation_data(container)
        _make_pf_input_map!(pf_e_data, container, sys)
    end
    return
end

# How to update the PowerFlowData given a component type. A bit duplicative of code in PowerFlows.jl.
_update_pf_data_component!(
    pf_data::PFS.PowerFlowData,
    ::Type{<:PSY.StaticInjection},
    index,
    t,
    value,
) = (pf_data.bus_activepower_injection[index, t] += value)
_update_pf_data_component!(
    pf_data::PFS.PowerFlowData,
    ::Type{<:PSY.ElectricLoad},
    index,
    t,
    value,
) = (pf_data.bus_activepower_withdrawals[index, t] += value)

function _write_value_to_pf_data!(
    pf_data::PFS.PowerFlowData,
    container::OptimizationContainer,
    key::OptimizationContainerKey,
    component_map)
    result = lookup_value(container, key)
    for (device_name, index) in component_map
        injection_values = result[device_name, :]
        for t in get_time_steps(container)
            value = jump_value(injection_values[t])
            _update_pf_data_component!(pf_data, get_component_type(key), index, t, value)
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
    input_map = get_input_key_map(pf_e_data)
    for (key, component_map) in input_map
        _write_value_to_pf_data!(pf_data, container, key, component_map)
    end
    return
end

_update_component(
    ::Type{<:Union{ActivePowerVariable, PowerOutput, ActivePowerTimeSeriesParameter}},
    comp::PSY.Component,
    value,
) = (comp.active_power = value)
# Sign is flipped for loads (TODO can we rely on some existing function that encodes this information?)
_update_component(
    ::Type{<:Union{ActivePowerVariable, PowerOutput, ActivePowerTimeSeriesParameter}},
    comp::PSY.ElectricLoad,
    value,
) = (comp.active_power = -value)
_update_component(::Type{PowerFlowVoltageAngle}, comp::PSY.Component, value) =
    comp.angle = value
_update_component(::Type{PowerFlowVoltageMagnitude}, comp::PSY.Component, value) =
    comp.magnitude = value

function update_pf_system!(
    sys::PSY.System,
    container::OptimizationContainer,
    input_map::Dict{<:OptimizationContainerKey, <:Any},
    time_step::Int,
)
    for (key, component_map) in input_map
        result = lookup_value(container, key)
        for (device_id, device_name) in component_map
            injection_values = result[device_id, :]
            comp = PSY.get_component(get_component_type(key), sys, device_name)
            val = jump_value(injection_values[time_step])
            _update_component(get_entry_type(key), comp, val)
        end
    end
end

"""
Update a `PowerFlowEvaluationData` containing a `PowerFlowContainer` that does not
`supports_multi_period` using a single `time_step` of the `OptimizationContainer`. To
properly keep track of outer step number, time steps must be passed in sequentially,
starting with 1.
"""
function update_pf_data!(
    pf_e_data::PowerFlowEvaluationData{PFS.PSSEExporter},
    container::OptimizationContainer,
    time_step::Int,
)
    pf_data = get_power_flow_data(pf_e_data)
    input_map = get_input_key_map(pf_e_data)
    update_pf_system!(PFS.get_system(pf_data), container, input_map, time_step)
    if !isnothing(pf_data.step)
        outer_step, _ = pf_data.step
        # time_step == 1 means we have rolled over to a new outer step
        # (TODO it works but seems a little brittle, consider redesigning)
        (time_step == 1) && (outer_step += 1)
        pf_data.step = (outer_step, time_step)
    end
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
    pf_data = get_power_flow_data(pf_e_data)
    if PFS.supports_multi_period(pf_data)
        update_pf_data!(pf_e_data, container)
        PFS.solve_powerflow!(pf_data)
    else
        for t in get_time_steps(container)
            update_pf_data!(pf_e_data, container, t)
            PFS.solve_powerflow!(pf_data)
        end
    end
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
