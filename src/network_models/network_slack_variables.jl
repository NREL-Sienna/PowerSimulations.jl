#! format: off
get_variable_multiplier(::SystemBalanceSlackUp, ::Type{<: Union{PSY.ACBus, PSY.Area, PSY.System}}, _) = 1.0
get_variable_multiplier(::SystemBalanceSlackDown, ::Type{<: Union{PSY.ACBus, PSY.Area, PSY.System}}, _) = -1.0
#! format: on

function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    ::PSY.System,
    network_model::NetworkModel{U},
) where {
    T <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    U <: Union{CopperPlatePowerModel, PTDFPowerModel},
}
    time_steps = get_time_steps(container)
    reference_buses = get_reference_buses(network_model)
    variable =
        add_variable_container!(container, T(), PSY.System, reference_buses, time_steps)

    for t in time_steps, bus in reference_buses
        variable[bus, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "slack_{$(T), $(bus), $t}",
            lower_bound = 0.0
        )
    end
    return
end

function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    sys::PSY.System,
    network_model::NetworkModel{U},
) where {
    T <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    U <: Union{AreaBalancePowerModel, AreaPTDFPowerModel},
}
    time_steps = get_time_steps(container)
    areas = get_name.(get_available_components(network_model, PSY.Area, sys))
    variable =
        add_variable_container!(container, T(), PSY.Area, areas, time_steps)

    for t in time_steps, area in areas
        variable[area, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "slack_{$(T), $(area), $t}",
            lower_bound = 0.0
        )
    end

    return
end

function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    sys::PSY.System,
    network_model::NetworkModel{U},
) where {
    T <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    U <: PM.AbstractActivePowerModel,
}
    time_steps = get_time_steps(container)
    radial_network_reduction = get_radial_network_reduction(network_model)
    if isempty(radial_network_reduction)
        bus_numbers =
            PSY.get_number.(get_available_components(network_model, PSY.ACBus, sys))
    else
        bus_numbers = collect(keys(PNM.get_bus_reduction_map(radial_network_reduction)))
    end

    variable = add_variable_container!(container, T(), PSY.ACBus, bus_numbers, time_steps)
    for t in time_steps, n in bus_numbers
        variable[n, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "slack_{$(T), $n, $t}",
            lower_bound = 0.0
        )
    end
    return
end

function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    sys::PSY.System,
    network_model::NetworkModel{U},
) where {
    T <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    U <: PM.AbstractPowerModel,
}
    time_steps = get_time_steps(container)
    radial_network_reduction = get_radial_network_reduction(network_model)
    if isempty(radial_network_reduction)
        bus_numbers =
            PSY.get_number.(get_available_components(network_model, PSY.ACBus, sys))
    else
        bus_numbers = collect(keys(PNM.get_bus_reduction_map(radial_network_reduction)))
    end
    variable_active =
        add_variable_container!(container, T(), PSY.ACBus, "P", bus_numbers, time_steps)
    variable_reactive =
        add_variable_container!(container, T(), PSY.ACBus, "Q", bus_numbers, time_steps)

    for t in time_steps, n in bus_numbers
        variable_active[n, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "slack_{p, $(T), $n, $t}",
            lower_bound = 0.0
        )
        variable_reactive[n, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "slack_{q, $(T), $n, $t}",
            lower_bound = 0.0
        )
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    sys::PSY.System,
    network_model::NetworkModel{T},
) where {T <: Union{CopperPlatePowerModel, PTDFPowerModel}}
    variable_up = get_variable(container, SystemBalanceSlackUp(), PSY.System)
    variable_dn = get_variable(container, SystemBalanceSlackDown(), PSY.System)
    reference_buses = get_reference_buses(network_model)

    for t in get_time_steps(container), n in reference_buses
        add_to_objective_invariant_expression!(
            container,
            (variable_dn[n, t] + variable_up[n, t]) * BALANCE_SLACK_COST,
        )
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    sys::PSY.System,
    network_model::NetworkModel{T},
) where {T <: Union{AreaBalancePowerModel, AreaPTDFPowerModel}}
    variable_up = get_variable(container, SystemBalanceSlackUp(), PSY.Area)
    variable_dn = get_variable(container, SystemBalanceSlackDown(), PSY.Area)
    areas = PSY.get_name.(get_available_components(network_model, PSY.Area, sys))

    for t in get_time_steps(container), n in areas
        add_to_objective_invariant_expression!(
            container,
            (variable_dn[n, t] + variable_up[n, t]) * BALANCE_SLACK_COST,
        )
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    sys::PSY.System,
    network_model::NetworkModel{T},
) where {T <: PM.AbstractActivePowerModel}
    variable_up = get_variable(container, SystemBalanceSlackUp(), PSY.ACBus)
    variable_dn = get_variable(container, SystemBalanceSlackDown(), PSY.ACBus)
    bus_numbers = axes(variable_up)[1]
    @assert_op bus_numbers == axes(variable_dn)[1]
    for t in get_time_steps(container), n in bus_numbers
        add_to_objective_invariant_expression!(
            container,
            (variable_dn[n, t] + variable_up[n, t]) * BALANCE_SLACK_COST,
        )
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    sys::PSY.System,
    network_model::NetworkModel{T},
) where {T <: PM.AbstractPowerModel}
    variable_p_up = get_variable(container, SystemBalanceSlackUp(), PSY.ACBus, "P")
    variable_p_dn = get_variable(container, SystemBalanceSlackDown(), PSY.ACBus, "P")
    variable_q_up = get_variable(container, SystemBalanceSlackUp(), PSY.ACBus, "Q")
    variable_q_dn = get_variable(container, SystemBalanceSlackDown(), PSY.ACBus, "Q")
    bus_numbers = axes(variable_p_up)[1]
    @assert_op bus_numbers == axes(variable_q_dn)[1]
    for t in get_time_steps(container), n in bus_numbers
        add_to_objective_invariant_expression!(
            container,
            (
                variable_p_dn[n, t] +
                variable_p_up[n, t] +
                variable_q_dn[n, t] +
                variable_q_up[n, t]
            ) * BALANCE_SLACK_COST,
        )
    end
    return
end
