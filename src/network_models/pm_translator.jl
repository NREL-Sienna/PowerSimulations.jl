const PM_MAP_TUPLE =
    NamedTuple{(:from_to, :to_from), Tuple{Tuple{Int, Int, Int}, Tuple{Int, Int, Int}}}

const PM_BUSTYPES = Dict{PSY.ACBusTypes, Int}(
    PSY.ACBusTypes.ISOLATED => 4,
    PSY.ACBusTypes.PQ => 1,
    PSY.ACBusTypes.PV => 2,
    PSY.ACBusTypes.REF => 3,
    PSY.ACBusTypes.SLACK => 3,
)

struct PMmap
    bus::Dict{Int, PSY.ACBus}
    arcs::Dict{PM_MAP_TUPLE, <:PSY.ACBranch}
    arcs_dc::Dict{PM_MAP_TUPLE, PSY.TwoTerminalHVDCLine}
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.PhaseShiftingTransformer,
    ::Type{PhaseAngleControl},
    ::Type{<:PM.AbstractDCPModel},
)
    PM_branch = Dict{String, Any}(
        "br_r" => PSY.get_r(branch),
        "rate_a" => PSY.get_rate(branch),
        "shift" => PSY.get_α(branch),
        "rate_b" => PSY.get_rate(branch),
        "br_x" => PSY.get_x(branch),
        "rate_c" => PSY.get_rate(branch),
        "g_to" => 0.0,
        "g_fr" => 0.0,
        "b_fr" => PSY.get_primary_shunt(branch) / 2,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "br_status" => 0.0, # Turn off the branch while keeping the function type stable
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "b_to" => PSY.get_primary_shunt(branch) / 2,
        "index" => ix,
        "angmin" => -π / 2,
        "angmax" => π / 2,
        "transformer" => true,
        "tap" => PSY.get_tap(branch),
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.PhaseShiftingTransformer,
    ::Type{D},
    ::Type{<:PM.AbstractPowerModel},
) where {D <: AbstractBranchFormulation}
    PM_branch = Dict{String, Any}(
        "br_r" => PSY.get_r(branch),
        "rate_a" => PSY.get_rate(branch),
        "shift" => PSY.get_α(branch),
        "rate_b" => PSY.get_rate(branch),
        "br_x" => PSY.get_x(branch),
        "rate_c" => PSY.get_rate(branch),
        "g_to" => 0.0,
        "g_fr" => 0.0,
        "b_fr" => PSY.get_primary_shunt(branch) / 2,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "b_to" => PSY.get_primary_shunt(branch) / 2,
        "index" => ix,
        "angmin" => -π / 2,
        "angmax" => π / 2,
        "transformer" => true,
        "tap" => PSY.get_tap(branch),
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.PhaseShiftingTransformer,
    ::Type{StaticBranchUnbounded},
    ::Type{<:PM.AbstractPowerModel},
)
    PM_branch = Dict{String, Any}(
        "br_r" => PSY.get_r(branch),
        "shift" => PSY.get_α(branch),
        "br_x" => PSY.get_x(branch),
        "g_to" => 0.0,
        "g_fr" => 0.0,
        "b_fr" => PSY.get_primary_shunt(branch) / 2,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "b_to" => PSY.get_primary_shunt(branch) / 2,
        "index" => ix,
        "angmin" => -π / 2,
        "angmax" => π / 2,
        "transformer" => true,
        "tap" => PSY.get_tap(branch),
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.Transformer2W,
    ::Type{<:AbstractBranchFormulation},
    ::Type{<:PM.AbstractPowerModel},
)
    PM_branch = Dict{String, Any}(
        "br_r" => PSY.get_r(branch),
        "rate_a" => PSY.get_rate(branch),
        "shift" => 0.0,
        "rate_b" => PSY.get_rate(branch),
        "br_x" => PSY.get_x(branch),
        "rate_c" => PSY.get_rate(branch),
        "g_to" => 0.0,
        "g_fr" => 0.0,
        "b_fr" => PSY.get_primary_shunt(branch) / 2,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "b_to" => PSY.get_primary_shunt(branch) / 2,
        "index" => ix,
        "angmin" => -π / 2,
        "angmax" => π / 2,
        "transformer" => true,
        "tap" => 1.0,
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.Transformer2W,
    ::Type{StaticBranchUnbounded},
    ::Type{<:PM.AbstractPowerModel},
)
    PM_branch = Dict{String, Any}(
        "br_r" => PSY.get_r(branch),
        "shift" => 0.0,
        "br_x" => PSY.get_x(branch),
        "g_to" => 0.0,
        "g_fr" => 0.0,
        "b_fr" => PSY.get_primary_shunt(branch) / 2,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "b_to" => PSY.get_primary_shunt(branch) / 2,
        "index" => ix,
        "angmin" => -π / 2,
        "angmax" => π / 2,
        "transformer" => true,
        "tap" => 1.0,
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.TapTransformer,
    ::Type{<:AbstractBranchFormulation},
    ::Type{<:PM.AbstractPowerModel},
)
    PM_branch = Dict{String, Any}(
        "br_r" => PSY.get_r(branch),
        "rate_a" => PSY.get_rate(branch),
        "shift" => 0.0,
        "rate_b" => PSY.get_rate(branch),
        "br_x" => PSY.get_x(branch),
        "rate_c" => PSY.get_rate(branch),
        "g_to" => 0.0,
        "g_fr" => 0.0,
        "b_fr" => PSY.get_primary_shunt(branch) / 2,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "b_to" => PSY.get_primary_shunt(branch) / 2,
        "index" => ix,
        "angmin" => -π / 2,
        "angmax" => π / 2,
        "transformer" => true,
        "tap" => PSY.get_tap(branch),
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.TapTransformer,
    ::Type{StaticBranchUnbounded},
    ::Type{<:PM.AbstractPowerModel},
)
    PM_branch = Dict{String, Any}(
        "br_r" => PSY.get_r(branch),
        "shift" => 0.0,
        "br_x" => PSY.get_x(branch),
        "g_to" => 0.0,
        "g_fr" => 0.0,
        "b_fr" => PSY.get_primary_shunt(branch) / 2,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "b_to" => PSY.get_primary_shunt(branch) / 2,
        "index" => ix,
        "angmin" => -π / 2,
        "angmax" => π / 2,
        "transformer" => true,
        "tap" => PSY.get_tap(branch),
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.ACBranch,
    ::Type{<:AbstractBranchFormulation},
    ::Type{<:PM.AbstractPowerModel},
)
    PM_branch = Dict{String, Any}(
        "br_r" => PSY.get_r(branch),
        "rate_a" => PSY.get_rate(branch),
        "shift" => 0.0,
        "rate_b" => PSY.get_rate(branch),
        "br_x" => PSY.get_x(branch),
        "rate_c" => PSY.get_rate(branch),
        "g_to" => 0.0,
        "g_fr" => 0.0,
        "b_fr" => PSY.get_b(branch).from,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "b_to" => PSY.get_b(branch).to,
        "index" => ix,
        "angmin" => PSY.get_angle_limits(branch).min,
        "angmax" => PSY.get_angle_limits(branch).max,
        "transformer" => false,
        "tap" => 1.0,
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.ACBranch,
    ::Type{StaticBranchUnbounded},
    ::Type{<:PM.AbstractPowerModel},
)
    PM_branch = Dict{String, Any}(
        "br_r" => PSY.get_r(branch),
        "shift" => 0.0,
        "br_x" => PSY.get_x(branch),
        "g_to" => 0.0,
        "g_fr" => 0.0,
        "b_fr" => PSY.get_b(branch).from,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "b_to" => PSY.get_b(branch).to,
        "index" => ix,
        "angmin" => PSY.get_angle_limits(branch).min,
        "angmax" => PSY.get_angle_limits(branch).max,
        "transformer" => false,
        "tap" => 1.0,
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.TwoTerminalHVDCLine,
    ::Type{HVDCTwoTerminalDispatch},
    ::Type{<:PM.AbstractDCPModel},
)
    PM_branch = Dict{String, Any}(
        "loss1" => PSY.get_loss(branch).l1,
        "mp_pmax" => PSY.get_reactive_power_limits_from(branch).max,
        "model" => 2,
        "shutdown" => 0.0,
        "pmaxt" => PSY.get_active_power_limits_to(branch).max,
        "pmaxf" => PSY.get_active_power_limits_from(branch).max,
        "startup" => 0.0,
        "loss0" => PSY.get_loss(branch).l0,
        "pt" => 0.0,
        "vt" => PSY.get_magnitude(PSY.get_arc(branch).to),
        "qmaxf" => PSY.get_reactive_power_limits_from(branch).max,
        "pmint" => PSY.get_active_power_limits_to(branch).min,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "mp_pmin" => PSY.get_reactive_power_limits_from(branch).min,
        "br_status" => 0.0,
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "index" => ix,
        "qmint" => PSY.get_reactive_power_limits_to(branch).min,
        "qf" => 0.0,
        "cost" => 0.0,
        "pminf" => PSY.get_active_power_limits_from(branch).min,
        "qt" => 0.0,
        "qminf" => PSY.get_reactive_power_limits_from(branch).min,
        "vf" => PSY.get_magnitude(PSY.get_arc(branch).from),
        "qmaxt" => PSY.get_reactive_power_limits_to(branch).max,
        "ncost" => 0,
        "pf" => 0.0,
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.TwoTerminalHVDCLine,
    ::Type{HVDCTwoTerminalDispatch},
    ::Type{<:PM.AbstractPowerModel},
)
    check_hvdc_line_limits_unidirectional(branch)
    PM_branch = Dict{String, Any}(
        "loss1" => PSY.get_loss(branch).l1,
        "mp_pmax" => PSY.get_reactive_power_limits_from(branch).max,
        "model" => 2,
        "shutdown" => 0.0,
        "pmaxt" => PSY.get_active_power_limits_to(branch).max,
        "pmaxf" => PSY.get_active_power_limits_from(branch).max,
        "startup" => 0.0,
        "loss0" => PSY.get_loss(branch).l0,
        "pt" => 0.0,
        "vt" => PSY.get_magnitude(PSY.get_arc(branch).to),
        "qmaxf" => PSY.get_reactive_power_limits_from(branch).max,
        "pmint" => PSY.get_active_power_limits_to(branch).min,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "mp_pmin" => PSY.get_reactive_power_limits_from(branch).min,
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "index" => ix,
        "qmint" => PSY.get_reactive_power_limits_to(branch).min,
        "qf" => 0.0,
        "cost" => 0.0,
        "pminf" => PSY.get_active_power_limits_from(branch).min,
        "qt" => 0.0,
        "qminf" => PSY.get_reactive_power_limits_from(branch).min,
        "vf" => PSY.get_magnitude(PSY.get_arc(branch).from),
        "qmaxt" => PSY.get_reactive_power_limits_to(branch).max,
        "ncost" => 0,
        "pf" => 0.0,
    )
    return PM_branch
end

function get_branch_to_pm(
    ix::Int,
    branch::PSY.TwoTerminalHVDCLine,
    ::Type{<:AbstractTwoTerminalDCLineFormulation},
    ::Type{<:PM.AbstractPowerModel},
)
    PM_branch = Dict{String, Any}(
        "loss1" => PSY.get_loss(branch).l1,
        "mp_pmax" => PSY.get_reactive_power_limits_from(branch).max,
        "model" => 2,
        "shutdown" => 0.0,
        "pmaxt" => PSY.get_active_power_limits_to(branch).max,
        "pmaxf" => PSY.get_active_power_limits_from(branch).max,
        "startup" => 0.0,
        "loss0" => PSY.get_loss(branch).l0,
        "pt" => 0.0,
        "vt" => PSY.get_magnitude(PSY.get_arc(branch).to),
        "qmaxf" => PSY.get_reactive_power_limits_from(branch).max,
        "pmint" => PSY.get_active_power_limits_to(branch).min,
        "f_bus" => PSY.get_number(PSY.get_arc(branch).from),
        "mp_pmin" => PSY.get_reactive_power_limits_from(branch).min,
        "br_status" => Float64(PSY.get_available(branch)),
        "t_bus" => PSY.get_number(PSY.get_arc(branch).to),
        "index" => ix,
        "qmint" => PSY.get_reactive_power_limits_to(branch).min,
        "qf" => 0.0,
        "cost" => 0.0,
        "pminf" => PSY.get_active_power_limits_from(branch).min,
        "qt" => 0.0,
        "qminf" => PSY.get_reactive_power_limits_from(branch).min,
        "vf" => PSY.get_magnitude(PSY.get_arc(branch).from),
        "qmaxt" => PSY.get_reactive_power_limits_to(branch).max,
        "ncost" => 0,
        "pf" => 0.0,
    )
    return PM_branch
end

function get_branches_to_pm(
    sys::PSY.System,
    network_model::NetworkModel{S},
    ::Type{T},
    branch_template::BranchModelContainer,
    start_idx = 0,
) where {T <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    PM_branches = Dict{String, Any}()
    PMmap_br = Dict{PM_MAP_TUPLE, T}()

    radial_network_reduction = get_radial_network_reduction(network_model)
    radial_branches_names = PNM.get_radial_branches(radial_network_reduction)
    for (d, device_model) in branch_template
        comp_type = get_component_type(device_model)
        if comp_type <: TwoTerminalHVDCTypes
            continue
        end
        !(comp_type <: T) && continue
        start_idx += length(PM_branches)
        filter_func = get_attribute(device_model, "filter_function")
        for (i, branch) in enumerate(get_available_components(comp_type, sys, filter_func))
            if PSY.get_name(branch) ∈ radial_branches_names
                @debug "Skipping branch $(PSY.get_name(branch)) since it is radial"
                continue
            end
            ix = i + start_idx
            PM_branches["$(ix)"] =
                get_branch_to_pm(ix, branch, get_formulation(device_model), S)
            if PM_branches["$(ix)"]["br_status"] == true
                f = PM_branches["$(ix)"]["f_bus"]
                t = PM_branches["$(ix)"]["t_bus"]
                PMmap_br[(from_to = (ix, f, t), to_from = (ix, t, f))] = branch
            end
        end
    end
    return PM_branches, PMmap_br
end

function get_branches_to_pm(
    sys::PSY.System,
    network_model::NetworkModel{S},
    ::Type{T},
    branch_template::BranchModelContainer,
    start_idx = 0,
) where {T <: TwoTerminalHVDCTypes, S <: PM.AbstractPowerModel}
    PM_branches = Dict{String, Any}()
    PMmap_br = Dict{PM_MAP_TUPLE, T}()

    for (d, device_model) in branch_template
        comp_type = get_component_type(device_model)
        !(comp_type <: T) && continue
        start_idx += length(PM_branches)
        filter_func = get_attribute(device_model, "filter_function")
        for (i, branch) in enumerate(get_available_components(comp_type, sys, filter_func))
            ix = i + start_idx
            PM_branches["$(ix)"] =
                get_branch_to_pm(ix, branch, get_formulation(device_model), S)
            if PM_branches["$(ix)"]["br_status"] == true
                f = PM_branches["$(ix)"]["f_bus"]
                t = PM_branches["$(ix)"]["t_bus"]
                PMmap_br[(from_to = (ix, f, t), to_from = (ix, t, f))] = branch
            end
        end
    end
    return PM_branches, PMmap_br
end

function get_buses_to_pm(buses::IS.FlattenIteratorWrapper{PSY.ACBus})
    PM_buses = Dict{String, Any}()
    PMmap_buses = Dict{Int, PSY.ACBus}()

    for bus in buses
        if PSY.get_bustype(bus) == PSY.ACBusTypes.ISOLATED
            continue
        end
        number = PSY.get_number(bus)
        PM_bus = Dict{String, Any}(
            "zone" => 1,
            "bus_i" => number,
            "bus_type" => PM_BUSTYPES[PSY.get_bustype(bus)],
            "vmax" => PSY.get_voltage_limits(bus).max,
            "area" => 1,
            "vmin" => PSY.get_voltage_limits(bus).min,
            "index" => PSY.get_number(bus),
            "va" => PSY.get_angle(bus),
            "vm" => PSY.get_magnitude(bus),
            "base_kv" => PSY.get_base_voltage(bus),
            "inj_p" => 0.0,
            "inj_q" => 0.0,
            "name" => PSY.get_name(bus),
        )
        PM_buses["$(number)"] = PM_bus
        PMmap_buses[number] = bus
    end
    return PM_buses, PMmap_buses
end

function pass_to_pm(sys::PSY.System, template::ProblemTemplate, time_periods::Int)
    ac_lines, PMmap_ac = get_branches_to_pm(
        sys,
        get_network_model(template),
        PSY.ACBranch,
        template.branches,
    )
    two_terminal_dc_lines, PMmap_dc = get_branches_to_pm(
        sys,
        get_network_model(template),
        TwoTerminalHVDCTypes,
        template.branches,
        length(ac_lines),
    )
    buses = get_available_components(PSY.ACBus, sys)
    pm_buses, PMmap_buses = get_buses_to_pm(buses)
    PM_translation = Dict{String, Any}(
        "bus" => pm_buses,
        "branch" => ac_lines,
        "baseMVA" => PSY.get_base_power(sys),
        "per_unit" => true,
        "storage" => Dict{String, Any}(),
        "dcline" => two_terminal_dc_lines,
        "gen" => Dict{String, Any}(),
        "switch" => Dict{String, Any}(),
        "shunt" => Dict{String, Any}(),
        "load" => Dict{String, Any}(),
    )

    # TODO: this function adds overhead in large number of time_steps
    # We can do better later.

    PM_translation = PM.replicate(PM_translation, time_periods)

    PM_map = PMmap(PMmap_buses, PMmap_ac, PMmap_dc)

    return PM_translation, PM_map
end
