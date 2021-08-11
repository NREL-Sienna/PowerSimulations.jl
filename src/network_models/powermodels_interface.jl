#################################################################################
# Comments
#
# - Ideally the net_injection variables would be bounded.  This can be done using an adhoc data model extention
# - the `instantiate_*_expr_model` functions combine `PM.instantiate_model` and the `build_*` methods
#################################################################################
# Model Definitions

""
function instantiate_nip_expr_model(data::Dict{String, Any}, model_constructor; kwargs...)
    return PM.instantiate_model(data, model_constructor, instantiate_nip_expr; kwargs...)
end

""
# replicates PM.build_mn_opf
function instantiate_nip_expr(pm::PM.AbstractPowerModel)
    for n in eachindex(PM.nws(pm))
        @assert !PM.ismulticonductor(pm, nw = n)
        PM.variable_bus_voltage(pm, nw = n)
        PM.variable_branch_power(pm, nw = n; bounded = false)
        PM.variable_dcline_power(pm, nw = n)

        PM.constraint_model_voltage(pm, nw = n)

        for i in PM.ids(pm, :ref_buses, nw = n)
            PM.constraint_theta_ref(pm, i, nw = n)
        end

        for i in PM.ids(pm, :bus, nw = n)
            constraint_power_balance_ni_expr(pm, i, nw = n)
        end

        for i in PM.ids(pm, :branch, nw = n)
            PM.constraint_ohms_yt_from(pm, i, nw = n)
            PM.constraint_ohms_yt_to(pm, i, nw = n)

            PM.constraint_voltage_angle_difference(pm, i, nw = n)
        end

        for i in PM.ids(pm, :dcline, nw = n)
            PM.constraint_dcline_power_losses(pm, i, nw = n)
        end
    end

    return
end

""
function instantiate_nip_ptdf_expr_model(
    data::Dict{String, Any},
    model_constructor;
    kwargs...,
)
    return PM.instantiate_model(
        data,
        PM.DCPPowerModel,
        instantiate_nip_ptdf_expr;
        ref_extensions = [PM.ref_add_connected_components!, PM.ref_add_sm!],
        kwargs...,
    )
end

""
# replicates PM.build_opf_ptdf
function instantiate_nip_ptdf_expr(pm::PM.AbstractPowerModel)
    for n in eachindex(PM.nws(pm))
        @assert !PM.ismulticonductor(pm, nw = n)

        #PM.variable_gen_power(pm) #connect P__* with these

        for i in PM.ids(pm, :bus, nw = n)
            if !haskey(PM.var(pm, n), :inj_p)
                PM.var(pm, n)[:inj_p] = Dict{Int, Any}()
            end
            PM.var(pm, n, :inj_p)[i] = PM.ref(pm, :bus, i, nw = n)["inj_p"] # use :nodal_balance_expr
        end

        PM.constraint_model_voltage(pm, nw = n)

        # this constraint is implicit in this model
        #for i in PM.ids(pm, :ref_buses, nw = n)
        #    PM.constraint_theta_ref(pm, i, nw = n)
        #end

        # done later with PSI copper_plate
        #for i in PM.ids(pm, :bus, nw = n)
        #    constraint_power_balance_ni_expr(pm, i, nw = n)
        #end
        for (i, branch) in PM.ref(pm, :branch, nw = n)
            if haskey(branch, "rate_a")
                PM.expression_branch_power_ohms_yt_from_ptdf(pm, i, nw = n)
                PM.expression_branch_power_ohms_yt_to_ptdf(pm, i, nw = n)
            end

            # done in PSI construct_branch!
            #PM.constraint_thermal_limit_from(pm, i, nw = n)
            #PM.constraint_thermal_limit_to(pm, i, nw = n)
        end
    end

    return
end

function instantiate_bfp_expr_model(data::Dict{String, Any}, model_constructor; kwargs...)
    return PM.instantiate_model(data, model_constructor, instantiate_bfp_expr; kwargs...)
end

""
# replicates PM.build_mn_opf_bf_strg
function instantiate_bfp_expr(pm::PM.AbstractPowerModel)
    for n in eachindex(PM.nws(pm))
        @assert !PM.ismulticonductor(pm, nw = n)
        PM.variable_bus_voltage(pm, nw = n)
        PM.variable_branch_power(pm, nw = n; bounded = false)
        PM.variable_dcline_power(pm, nw = n)

        PM.constraint_model_current(pm, nw = n)

        for i in PM.ids(pm, :ref_buses, nw = n)
            PM.constraint_theta_ref(pm, i, nw = n)
        end

        for i in PM.ids(pm, :bus, nw = n)
            constraint_power_balance_ni_expr(pm, i, nw = n)
        end

        for i in PM.ids(pm, :branch, nw = n)
            PM.constraint_power_losses(pm, i, nw = n)
            PM.constraint_voltage_magnitude_difference(pm, i, nw = n)

            PM.constraint_voltage_angle_difference(pm, i, nw = n)
        end

        for i in PM.ids(pm, :dcline, nw = n)
            PM.constraint_dcline_power_losses(pm, i, nw = n)
        end
    end

    return
end

function instantiate_vip_expr_model(data::Dict{String, Any}, model_constructor; kwargs...)
    throw(error("VI Models not currently supported"))
end

#################################################################################
# Model Extention Functions

""
function constraint_power_balance_ni_expr(
    pm::PM.AbstractPowerModel,
    i::Int;
    nw::Int = pm.cnw,
)
    if !haskey(PM.con(pm, nw), :power_balance_p)
        PM.con(pm, nw)[:power_balance_p] = Dict{Int, JuMP.ConstraintRef}()
    end
    if !haskey(PM.con(pm, nw), :power_balance_q)
        PM.con(pm, nw)[:power_balance_q] = Dict{Int, JuMP.ConstraintRef}()
    end

    bus_arcs = PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = PM.ref(pm, nw, :bus_arcs_dc, i)

    inj_p_expr = PM.ref(pm, nw, :bus, i, "inj_p")
    inj_q_expr = PM.ref(pm, nw, :bus, i, "inj_q")

    constraint_power_balance_ni_expr(
        pm,
        nw,
        i,
        bus_arcs,
        bus_arcs_dc,
        inj_p_expr,
        inj_q_expr,
    )

    return
end

""
function constraint_power_balance_ni_expr(
    pm::PM.AbstractPowerModel,
    n::Int,
    i::Int,
    bus_arcs,
    bus_arcs_dc,
    inj_p_expr,
    inj_q_expr,
)
    p = PM.var(pm, n, :p)
    q = PM.var(pm, n, :q)
    p_dc = PM.var(pm, n, :p_dc)
    q_dc = PM.var(pm, n, :q_dc)

    PM.con(pm, n, :power_balance_p)[i] = JuMP.@constraint(
        pm.model,
        sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == inj_p_expr
    )
    PM.con(pm, n, :power_balance_q)[i] = JuMP.@constraint(
        pm.model,
        sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == inj_q_expr
    )

    return
end

""
function constraint_current_balance_ni_expr(
    pm::PM.AbstractPowerModel,
    i::Int;
    nw::Int = pm.cnw,
)
    if !haskey(PM.con(pm, nw), :kcl_cr)
        PM.con(pm, nw)[:kcl_cr] = Dict{Int, JuMP.ConstraintRef}()
    end
    if !haskey(PM.con(pm, nw), :kcl_ci)
        PM.con(pm, nw)[:kcl_ci] = Dict{Int, JuMP.ConstraintRef}()
    end

    bus_arcs = PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = PM.ref(pm, nw, :bus_arcs_dc, i)

    inj_p_expr = PM.ref(pm, nw, :bus, i, "inj_p")
    inj_q_expr = PM.ref(pm, nw, :bus, i, "inj_q")

    constraint_current_balance_ni_expr(
        pm,
        nw,
        i,
        bus_arcs,
        bus_arcs_dc,
        inj_p_expr,
        inj_q_expr,
    )

    return
end

""
function constraint_current_balance_ni_expr(
    pm::PM.AbstractPowerModel,
    n::Int,
    i::Int,
    bus_arcs,
    bus_arcs_dc,
    inj_p_expr,
    inj_q_expr,
)
    p = PM.var(pm, n, :p)
    q = PM.var(pm, n, :q)
    p_dc = PM.var(pm, n, :p_dc)
    q_dc = PM.var(pm, n, :q_dc)

    PM.con(pm, n, :power_balance_p)[i] = JuMP.@constraint(
        pm.model,
        sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == inj_p_expr
    )
    PM.con(pm, n, :power_balance_q)[i] = JuMP.@constraint(
        pm.model,
        sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == inj_q_expr
    )

    return
end

"active power only models ignore reactive power variables"
function variable_reactive_net_injection(pm::PM.AbstractActivePowerModel; kwargs...)
    return
end

""
function constraint_power_balance_ni_expr(
    pm::PM.AbstractActivePowerModel,
    n::Int,
    i::Int,
    bus_arcs,
    bus_arcs_dc,
    inj_p_expr,
    _,
)
    p = PM.var(pm, n, :p)
    p_dc = PM.var(pm, n, :p_dc)

    PM.con(pm, n, :power_balance_p)[i] = JuMP.@constraint(
        pm.model,
        sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == inj_p_expr
    )

    return
end

""
function powermodels_network!(
    optimization_container::OptimizationContainer,
    system_formulation::Type{S},
    sys::PSY.System,
    template::OperationsProblemTemplate,
    instantiate_model = instantiate_nip_expr_model,
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(optimization_container)
    pm_data, PM_map = pass_to_pm(sys, template, time_steps[end])
    buses = PSY.get_components(PSY.Bus, sys)

    remove_undef!(optimization_container.expressions[:nodal_balance_active])
    remove_undef!(optimization_container.expressions[:nodal_balance_reactive])

    for t in time_steps, bus in buses
        pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["inj_p"] =
            optimization_container.expressions[:nodal_balance_active][bus.number, t]
        pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["inj_q"] =
            optimization_container.expressions[:nodal_balance_reactive][bus.number, t]
    end

    optimization_container.pm = instantiate_model(
        pm_data,
        system_formulation,
        jump_model = optimization_container.JuMPmodel,
    )
    optimization_container.pm.ext[:PMmap] = PM_map

    return
end

""
function powermodels_network!(
    optimization_container::OptimizationContainer,
    system_formulation::Type{S},
    sys::PSY.System,
    template::OperationsProblemTemplate,
    instantiate_model = instantiate_nip_expr_model,
) where {S <: PM.AbstractActivePowerModel}
    time_steps = model_time_steps(optimization_container)
    pm_data, PM_map = pass_to_pm(sys, template, time_steps[end])
    buses = PSY.get_components(PSY.Bus, sys)

    remove_undef!(optimization_container.expressions[:nodal_balance_active])

    for t in time_steps, bus in buses
        pm_data["nw"]["$(t)"]["bus"]["$(PSY.get_number(bus))"]["inj_p"] =
            optimization_container.expressions[:nodal_balance_active][
                PSY.get_number(bus),
                t,
            ]
        # pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["inj_q"] = 0.0
    end

    optimization_container.pm = instantiate_model(
        pm_data,
        system_formulation,
        jump_model = optimization_container.JuMPmodel,
    )
    optimization_container.pm.ext[:PMmap] = PM_map

    return
end

#### PM accessor functions ########

function PMvarmap(::Type{S}) where {S <: PM.AbstractDCPModel}
    pm_var_map = Dict{Type, Dict{Symbol, Union{String, NamedTuple}}}()

    pm_var_map[PSY.Bus] = Dict(:va => THETA)
    pm_var_map[PSY.ACBranch] =
        Dict(:p => (from_to = FlowActivePowerVariable, to_from = nothing))
    pm_var_map[PSY.DCBranch] =
        Dict(:p_dc => (from_to = FlowActivePowerVariable, to_from = nothing))

    return pm_var_map
end

function PMvarmap(::Type{S}) where {S <: PM.AbstractActivePowerModel}
    pm_var_map = Dict{Type, Dict{Symbol, Union{String, NamedTuple}}}()

    pm_var_map[PSY.Bus] = Dict(:va => THETA)
    pm_var_map[PSY.ACBranch] = Dict(:p => FlowActivePowerFromToVariable)
    pm_var_map[PSY.DCBranch] = Dict(
        :p_dc => (
            from_to = FlowActivePowerFromToVariable,
            to_from = FlowActivePowerToFromVariable,
        ),
    )

    return pm_var_map
end

function PMvarmap(::Type{PTDFPowerModel})
    pm_var_map = Dict{Type, Dict{Symbol, Union{String, NamedTuple}}}()

    pm_var_map[PSY.Bus] = Dict()
    pm_var_map[PSY.ACBranch] = Dict()
    pm_var_map[PSY.DCBranch] = Dict()

    return pm_var_map
end

function PMvarmap(::Type{S}) where {S <: PM.AbstractPowerModel}
    pm_var_map = Dict{Type, Dict{Symbol, Union{String, NamedTuple}}}()

    pm_var_map[PSY.Bus] = Dict(:va => THETA, :vm => VM)
    pm_var_map[PSY.ACBranch] = Dict(
        :p => (
            from_to = FlowActivePowerFromToVariable,
            to_from = FlowActivePowerToFromVariable,
        ),
        :q => (
            from_to = FlowReactivePowerFromToVariable,
            to_from = FlowReactivePowerToFromVariable,
        ),
    )
    pm_var_map[PSY.DCBranch] = Dict(
        :p_dc => (from_to = FlowActivePowerVariable, to_from = nothing),
        :q_dc => (
            from_to = FlowReactivePowerFromToVariable,
            to_from = FlowReactivePowerToFromVariable,
        ),
    )

    return pm_var_map
end

function PMconmap(::Type{S}) where {S <: PM.AbstractActivePowerModel}
    pm_con_map = Dict{Type, Dict{Symbol, String}}()

    pm_con_map[PSY.Bus] = Dict(:power_balance_p => NODAL_BALANCE_ACTIVE)
    return pm_con_map
end

function PMconmap(::Type{S}) where {S <: PM.AbstractPowerModel}
    pm_con_map = Dict{Type, Dict{Symbol, String}}()

    pm_con_map[PSY.Bus] = Dict(
        :power_balance_p => NODAL_BALANCE_ACTIVE,
        :power_balance_q => NODAL_BALANCE_REACTIVE,
    )
    return pm_con_map
end

function PMexprmap(::Type{S}) where {S <: PM.AbstractPowerModel}
    pm_expr_map = Dict{
        Type,
        NamedTuple{
            (:pm_expr, :psi_con),
            Tuple{Dict{Symbol, Union{String, NamedTuple}}, Symbol},
        },
    }()

    return pm_expr_map
end

function PMexprmap(::Type{PTDFPowerModel})
    pm_expr_map = Dict{
        Type,
        NamedTuple{
            (:pm_expr, :psi_con),
            Tuple{Dict{Symbol, Union{String, NamedTuple}}, Symbol},
        },
    }()

    pm_expr_map[PSY.ACBranch] = (
        pm_expr = Dict(:p => (from_to = FlowActivePowerVariable, to_from = nothing)),
        psi_con = Symbol(NETWORK_FLOW),
    )

    return pm_expr_map
end

function add_pm_var_refs!(
    optimization_container::OptimizationContainer,
    system_formulation::Type{S},
    ::PSY.System,
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(optimization_container)
    bus_dict = optimization_container.pm.ext[:PMmap].bus
    ACbranch_dict = optimization_container.pm.ext[:PMmap].arcs
    ACbranch_types = typeof.(values(ACbranch_dict))
    DCbranch_dict = optimization_container.pm.ext[:PMmap].arcs_dc
    DCbranch_types = typeof.(values(DCbranch_dict))

    pm_var_types = keys(PM.var(optimization_container.pm, 1))

    pm_var_map = PMvarmap(system_formulation)

    for (pm_v, ps_v) in pm_var_map[PSY.Bus]
        if pm_v in pm_var_types
            container = PSI.container_spec(
                JuMP.VariableRef,
                [PSY.get_name(b) for b in values(bus_dict)],
                time_steps,
            )
            assign_variable!(optimization_container, ps_v, PSY.Bus, container)
            for t in time_steps, (pm_bus, bus) in bus_dict
                name = PSY.get_name(bus)
                container[name, t] = PM.var(optimization_container.pm, t, pm_v)[pm_bus] # pm_vars[pm_v][pm_bus]
            end
        end
    end

    add_pm_var_refs!(
        optimization_container,
        PSY.ACBranch,
        ACbranch_types,
        ACbranch_dict,
        pm_var_map,
        pm_var_types,
        time_steps,
    )
    add_pm_var_refs!(
        optimization_container,
        PSY.DCBranch,
        DCbranch_types,
        DCbranch_dict,
        pm_var_map,
        pm_var_types,
        time_steps,
    )
end

function add_pm_var_refs!(
    optimization_container::OptimizationContainer,
    d_class::Type,
    device_types::Vector,
    pm_map::Dict,
    pm_var_map::Dict,
    pm_var_types::Base.KeySet,
    time_steps::UnitRange{Int},
)
    for d_type in Set(device_types)
        devices = [d for d in pm_map if typeof(d[2]) == d_type]
        for (pm_v, ps_v) in pm_var_map[d_class]
            if pm_v in pm_var_types
                for dir in fieldnames(typeof(ps_v))
                    var_type = getfield(ps_v, dir)
                    var_type === nothing && continue
                    container = PSI.container_spec(
                        JuMP.VariableRef,
                        [PSY.get_name(d[2]) for d in devices],
                        time_steps,
                    )
                    assign_variable!(
                        optimization_container,
                        make_variable_name(var_type, d_type),
                        container,
                    )
                    for t in time_steps, (pm_d, d) in devices
                        var =
                            PM.var(optimization_container.pm, t, pm_v, getfield(pm_d, dir))
                        container[PSY.get_name(d), t] = var
                    end
                end
            end
        end
    end
end

function add_pm_con_refs!(
    optimization_container::OptimizationContainer,
    system_formulation::Type{S},
    ::PSY.System,
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(optimization_container)
    bus_dict = optimization_container.pm.ext[:PMmap].bus

    pm_con_names = [
        k for k in keys(PM.con(optimization_container.pm, 1)) if
        !isempty(PM.con(optimization_container.pm, 1, k))
    ]

    pm_con_map = PMconmap(system_formulation)
    for (pm_v, ps_v) in pm_con_map[PSY.Bus]
        if pm_v in pm_con_names
            container = PSI.add_cons_container!(
                optimization_container,
                make_constraint_name(ps_v, PSY.Bus),
                [PSY.get_name(b) for b in values(bus_dict)],
                time_steps,
            )
            for t in time_steps, (pm_bus, bus) in bus_dict
                name = PSY.get_name(bus)
                container[name, t] = PM.con(optimization_container.pm, t, pm_v)[pm_bus]
            end
        end
    end
end

function add_pm_expr_refs!(
    optimization_container::OptimizationContainer,
    system_formulation::Type{S},
    ::PSY.System,
) where {S <: PM.AbstractPowerModel}
    time_steps = model_time_steps(optimization_container)

    ACbranch_dict = optimization_container.pm.ext[:PMmap].arcs
    ACbranch_types = typeof.(values(ACbranch_dict))

    pm_var_types = keys(PM.var(optimization_container.pm, 1))
    pm_expr_map = PMexprmap(system_formulation)

    add_pm_expr_refs!(
        optimization_container,
        PSY.ACBranch,
        ACbranch_types,
        ACbranch_dict,
        pm_expr_map,
        pm_var_types,
        time_steps,
    )
end

function add_pm_expr_refs!(
    optimization_container::OptimizationContainer,
    d_class::Type,
    device_types::Vector,
    pm_map::Dict,
    pm_expr_map::Dict,
    pm_var_types::Base.KeySet,
    time_steps::UnitRange{Int},
)
    for d_type in Set(device_types)
        for (pm_expr_var, ps_v) in pm_expr_map[d_class].pm_expr
            if pm_expr_var in pm_var_types
                pm_devices = keys(PM.var(optimization_container.pm, pm_expr_var, nw = 1))
                mapped_pm_devices = Vector()
                mapped_ps_devices = Vector{d_type}()
                for d in pm_map
                    if typeof(d[2]) == d_type &&
                       d[1].from_to ∈ pm_devices &&
                       d[1].to_from ∈ pm_devices
                        push!(mapped_pm_devices, d[1])
                        push!(mapped_ps_devices, d[2])
                    end
                end
                isempty(mapped_ps_devices) && continue
                mapped_ps_device_names = PSY.get_name.(mapped_ps_devices)

                # add variable in psi
                # add psi_var = pm_expr_var as constraint
                for dir in fieldnames(typeof(ps_v))
                    var_type = getfield(ps_v, dir)
                    var_type === nothing && continue

                    add_variable!(
                        optimization_container,
                        var_type(),
                        mapped_ps_devices,
                        StaticBranchUnbounded(),
                    )
                    psi_var_container = get_variable(
                        optimization_container,
                        make_variable_name(var_type, d_type),
                    )

                    con_name = make_constraint_name(pm_expr_map[d_class].psi_con, d_type)
                    psi_con_container = add_cons_container!(
                        optimization_container,
                        con_name,
                        mapped_ps_device_names,
                        time_steps,
                    )
                    for t in time_steps,
                        (pm_d, name) in zip(mapped_pm_devices, mapped_ps_device_names)

                        pm_expr = PM.var(
                            optimization_container.pm,
                            t,
                            pm_expr_var,
                            getfield(pm_d, dir),
                        )
                        psi_con_container[name, t] = JuMP.@constraint(
                            optimization_container.JuMPmodel,
                            psi_var_container[name, t] == pm_expr
                        )
                    end
                end
            end
        end
    end
end
