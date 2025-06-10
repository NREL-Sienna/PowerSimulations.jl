# Defines the order of precedence for each type of information that could be sent to PowerFlows.jl
const PF_INPUT_KEY_PRECEDENCES = Dict(
    :active_power => [ActivePowerVariable, PowerOutput, ActivePowerTimeSeriesParameter],
    :reactive_power => [ReactivePowerVariable, ReactivePowerTimeSeriesParameter],
    :voltage_angle_export => [PowerFlowVoltageAngle, VoltageAngle],
    :voltage_magnitude_export => [PowerFlowVoltageMagnitude, VoltageMagnitude],
    :voltage_angle_opf => [VoltageAngle],
    :voltage_magnitude_opf => [VoltageMagnitude],
)

const RELEVANT_COMPONENTS_SELECTOR =
    PSY.make_selector(Union{PSY.StaticInjection, PSY.Bus, PSY.Branch})

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

# Trait that determines which types of information are needed for each type of power flow
pf_input_keys(::PFS.ABAPowerFlowData) =
    [:active_power]
pf_input_keys(::PFS.PTDFPowerFlowData) =
    [:active_power]
pf_input_keys(::PFS.vPTDFPowerFlowData) =
    [:active_power]
pf_input_keys(::PFS.ACPowerFlowData) =
    [:active_power, :reactive_power, :voltage_angle_opf, :voltage_magnitude_opf]
pf_input_keys(::PFS.PSSEExporter) =
    [:active_power, :reactive_power, :voltage_angle_export, :voltage_magnitude_export]

# Maps the StaticInjection component type by name to the
# index in the PowerFlow data arrays going from Bus number to bus index
function _make_temp_component_map(pf_data::PFS.PowerFlowData, sys::PSY.System)
    temp_component_map = Dict{DataType, Dict{String, Int}}()
    available_injectors = PSY.get_available_components(PSY.StaticInjection, sys)
    bus_lookup = PFS.get_bus_lookup(pf_data)
    for comp in available_injectors
        comp_type = typeof(comp)
        bus_dict = get!(temp_component_map, comp_type, Dict{String, Int}())
        bus_number = PSY.get_number(PSY.get_bus(comp))
        bus_dict[get_name(comp)] = bus_lookup[bus_number]
    end
    # we need this to be able to export the voltage magnitude and voltage angles to data
    temp_component_map[PSY.ACBus] =
        Dict(
            PSY.get_name(c) => bus_lookup[PSY.get_number(c)] for
            c in get_components(PSY.ACBus, sys)
        )
    return temp_component_map
end

_get_temp_component_map_lhs(comp::PSY.Component) = PSY.get_name(comp)
_get_temp_component_map_lhs(comp::PSY.Bus) = PSY.get_number(comp)

# Creates dicts of components by type
function _make_temp_component_map(::PFS.SystemPowerFlowContainer, sys::PSY.System)
    temp_component_map =
        Dict{DataType, Dict{Union{String, Int64}, String}}()
    relevant_components = PSY.get_available_components(RELEVANT_COMPONENTS_SELECTOR, sys)
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
    pf_e_data.input_key_map = Dict{Symbol, Dict{OptimizationContainerKey, map_type}}()

    # available_keys is a vector of Pair{OptimizationContainerKey, data} containing all possibly relevant data sources to iterate over
    available_keys = vcat(
        [
            collect(pairs(f(container))) for
            f in [get_variables, get_aux_variables, get_parameters]
        ]...,
    )
    # Separate map for each category
    for category in pf_input_keys(pf_data)
        # Map that persists to store the bus index to which the variable maps in the PowerFlowData, etc.
        pf_data_opt_container_map = Dict{OptimizationContainerKey, map_type}()
        @info "Adding input map to send $category to $(nameof(typeof(pf_data)))"
        precedence = PF_INPUT_KEY_PRECEDENCES[category]
        added_injection_types = DataType[]
        # For each data source that is relevant to this category in order of precedence,
        # loop over the component types where data exists at that source and record the
        # association
        for entry_type in precedence
            for (key, val) in available_keys
                if get_entry_type(key) === entry_type
                    comp_type = get_component_type(key)
                    # Skip types that have already been handled by something of higher precedence
                    if comp_type in added_injection_types
                        continue
                    end
                    push!(added_injection_types, comp_type)

                    name_bus_ix_map = map_type()
                    comp_names =
                        if (key isa ParameterKey)
                            get_component_names(get_attributes(val))
                        else
                            axes(val)[1]
                        end
                    for comp_name in comp_names
                        name_bus_ix_map[comp_name] =
                            temp_component_map[comp_type][comp_name]
                    end
                    pf_data_opt_container_map[key] = name_bus_ix_map
                end
            end
        end
        pf_e_data.input_key_map[category] = pf_data_opt_container_map
    end
    return
end

# Trait that determines what branch aux vars we can get from each PowerFlowContainer
branch_aux_vars(::PFS.ACPowerFlowData) =
    [PowerFlowLineReactivePowerFromTo, PowerFlowLineReactivePowerToFrom,
        PowerFlowLineActivePowerFromTo, PowerFlowLineActivePowerToFrom]
branch_aux_vars(::PFS.ABAPowerFlowData) =
    [PowerFlowLineActivePowerFromTo, PowerFlowLineActivePowerToFrom]
branch_aux_vars(::PFS.PTDFPowerFlowData) =
    [PowerFlowLineActivePowerFromTo, PowerFlowLineActivePowerToFrom]
branch_aux_vars(::PFS.vPTDFPowerFlowData) =
    [PowerFlowLineActivePowerFromTo, PowerFlowLineActivePowerToFrom]
branch_aux_vars(::PFS.PSSEExporter) = DataType[]

# Same for bus aux vars
bus_aux_vars(data::PFS.ACPowerFlowData) =
    if data.calculate_loss_factors
        [PowerFlowVoltageAngle, PowerFlowVoltageMagnitude, PowerFlowLossFactors]
    else
        [PowerFlowVoltageAngle, PowerFlowVoltageMagnitude]
    end
bus_aux_vars(::PFS.ABAPowerFlowData) = [PowerFlowVoltageAngle]
bus_aux_vars(::PFS.PTDFPowerFlowData) = DataType[]
bus_aux_vars(::PFS.vPTDFPowerFlowData) = DataType[]
bus_aux_vars(::PFS.PSSEExporter) = DataType[]

function _get_branch_component_tuples(pfd::PFS.PowerFlowData)
    branch_types = PFS.get_branch_type(pfd)
    return [(branch_types[val], key) for (key, val) in pairs(PFS.get_branch_lookup(pfd))]
end

_get_branch_component_tuples(pfd::PFS.SystemPowerFlowContainer) = [
    (typeof(c), get_name(c)) for
    c in PSY.get_available_components(PSY.Branch, PFS.get_system(pfd))
]

_get_bus_component_tuples(pfd::PFS.PowerFlowData) =
    tuple.(PSY.ACBus, keys(PFS.get_bus_lookup(pfd)))  # get_bus_type returns a ACBusTypes, not the DataType we need here

_get_bus_component_tuples(pfd::PFS.SystemPowerFlowContainer) =
    [
        (typeof(c), PSY.get_number(c)) for
        c in PSY.get_available_components(PSY.Bus, PFS.get_system(pfd))
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
    ::Val{:active_power},
    ::Type{<:PSY.StaticInjection},
    index,
    t,
    value,
) = (pf_data.bus_activepower_injection[index, t] += value)
_update_pf_data_component!(
    pf_data::PFS.PowerFlowData,
    ::Val{:active_power},
    ::Type{<:PSY.ElectricLoad},
    index,
    t,
    value,
) = (pf_data.bus_activepower_withdrawals[index, t] -= value)
_update_pf_data_component!(
    pf_data::PFS.PowerFlowData,
    ::Val{:reactive_power},
    ::Type{<:PSY.StaticInjection},
    index,
    t,
    value,
) = (pf_data.bus_reactivepower_injection[index, t] += value)
_update_pf_data_component!(
    pf_data::PFS.PowerFlowData,
    ::Val{:reactive_power},
    ::Type{<:PSY.ElectricLoad},
    index,
    t,
    value,
) = (pf_data.bus_reactivepower_withdrawals[index, t] -= value)
_update_pf_data_component!(
    pf_data::PFS.PowerFlowData,
    ::Union{Val{:voltage_angle_export}, Val{:voltage_angle_opf}},
    ::Type{<:PSY.ACBus},
    index,
    t,
    value,
) = (pf_data.bus_angles[index, t] = value)
_update_pf_data_component!(
    pf_data::PFS.PowerFlowData,
    ::Union{Val{:voltage_magnitude_export}, Val{:voltage_magnitude_opf}},
    ::Type{<:PSY.ACBus},
    index,
    t,
    value,
) = (pf_data.bus_magnitude[index, t] = value)

function _write_value_to_pf_data!(
    pf_data::PFS.PowerFlowData,
    category::Symbol,
    container::OptimizationContainer,
    key::OptimizationContainerKey,
    component_map)
    result = lookup_value(container, key)
    for (device_name, index) in component_map
        injection_values = result[device_name, :]
        for t in get_time_steps(container)
            value = jump_value(injection_values[t])
            _update_pf_data_component!(
                pf_data,
                Val(category),
                get_component_type(key),
                index,
                t,
                value,
            )
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
    for (category, inputs) in input_map
        @info "Writing $category to $(nameof(typeof(pf_data)))"
        for (key, component_map) in inputs
            _write_value_to_pf_data!(pf_data, category, container, key, component_map)
        end
    end
    return
end

_update_component!(comp::PSY.Component, ::Val{:active_power}, value) =
    (comp.constant_active_power = -value * sys_base / PSY.get_base_power(comp))
_update_component!(comp::PSY.Component, ::Val{:reactive_power}, value) =
    (comp.constant_reactive_power = -value * sys_base / PSY.get_base_power(comp))
    
# PERF we use direct dot access here, and implement our own unit conversions, for performance and convenience
_update_component!(comp::PSY.Component, ::Val{:active_power}, value, sys_base) =
    (comp.active_power = value * sys_base / PSY.get_base_power(comp))
# Sign is flipped for loads (TODO can we rely on some existing function that encodes this information?)
_update_component!(comp::PSY.ElectricLoad, ::Val{:active_power}, value, sys_base) =
    (comp.active_power = -value * sys_base / PSY.get_base_power(comp))
_update_component!(comp::PSY.Component, ::Val{:reactive_power}, value, sys_base) =
    (comp.reactive_power = value * sys_base / PSY.get_base_power(comp))
_update_component!(comp::PSY.ElectricLoad, ::Val{:reactive_power}, value, sys_base) =
    (comp.reactive_power = -value * sys_base / PSY.get_base_power(comp))
_update_component!(
    comp::PSY.ACBus,
    ::Union{Val{:voltage_angle_export}, Val{:voltage_angle_opf}},
    value, sys_base,
) =
    comp.angle = value
_update_component!(
    comp::PSY.ACBus,
    ::Union{Val{:voltage_magnitude_export}, Val{:voltage_magnitude_opf}},
    value, sys_base,
) =
    comp.magnitude = value

function update_pf_system!(
    sys::PSY.System,
    container::OptimizationContainer,
    input_map::Dict{Symbol, <:Dict{OptimizationContainerKey, <:Any}},
    time_step::Int,
)
    for (category, inputs) in input_map
        @debug "Writing $category to (possibly internal) System"
        for (key, component_map) in inputs
            result = lookup_value(container, key)
            for (device_id, device_name) in component_map
                injection_values = result[device_id, :]
                comp = PSY.get_component(get_component_type(key), sys, device_name)
                val = jump_value(injection_values[time_step])
                _update_component!(comp, Val(category), val, get_base_power(container))
            end
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
        outer_step, _... = pf_data.step
        # time_step == 1 means we have rolled over to a new outer step
        # NOTE this is a bit brittle but there is currently no way of getting this
        # information from upstream, may change in the future
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
_get_pf_result(::Type{PowerFlowLineReactivePowerFromTo}, pf_data::PFS.PowerFlowData) =
    PFS.get_branch_reactivepower_flow_from_to(pf_data)
_get_pf_result(::Type{PowerFlowLineReactivePowerToFrom}, pf_data::PFS.PowerFlowData) =
    PFS.get_branch_reactivepower_flow_to_from(pf_data)
_get_pf_result(::Type{PowerFlowLineActivePowerFromTo}, pf_data::PFS.PowerFlowData) =
    PFS.get_branch_activepower_flow_from_to(pf_data)
_get_pf_result(::Type{PowerFlowLineActivePowerToFrom}, pf_data::PFS.PowerFlowData) =
    PFS.get_branch_activepower_flow_to_from(pf_data)
_get_pf_result(::Type{PowerFlowLossFactors}, pf_data::PFS.PowerFlowData) =
    pf_data.loss_factors

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
