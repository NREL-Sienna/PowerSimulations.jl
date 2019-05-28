#################################################################################
# Questions
#
# - why do exported functions (e.g. ids, var, con, ref) need pacakge qualification?
# - why do non-qualified exported functions (e.g. ids, var) still throw warnings?
#
#
# Comments
#
# - Ideally the net_injection variables would be bounded.  This can be done using an adhoc data model extention
#


#################################################################################
###

function psi_ref!(pm::PM.GenericPowerModel)
    psi_ref!(pm.ref[:nw])
end

function psi_ref!(nw_refs::Dict)
    for (nw, ref) in nw_refs

        ### filter out inactive components ###
        ref[:bus] = Dict(x for x in ref[:bus] if x.second["bus_type"] != 4)
        ref[:load] = Dict(x for x in ref[:load] if (x.second["status"] == 1 && x.second["load_bus"] in keys(ref[:bus])))
        ref[:shunt] = Dict(x for x in ref[:shunt] if (x.second["status"] == 1 && x.second["shunt_bus"] in keys(ref[:bus])))
        ref[:gen] = Dict(x for x in ref[:gen] if (x.second["gen_status"] == 1 && x.second["gen_bus"] in keys(ref[:bus])))
        ref[:storage] = Dict(x for x in ref[:storage] if (x.second["status"] == 1 && x.second["storage_bus"] in keys(ref[:bus])))
        ref[:branch] = Dict(x for x in ref[:branch] if (x.second["br_status"] == 1 && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))
        ref[:dcline] = Dict(x for x in ref[:dcline] if (x.second["br_status"] == 1 && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))

        ### bus connected component lookups ###
        bus_loads = Dict((i, Int64[]) for (i,bus) in ref[:bus])
        for (i, load) in ref[:load]
            push!(bus_loads[load["load_bus"]], i)
        end
        ref[:bus_loads] = bus_loads

        bus_shunts = Dict((i, Int64[]) for (i,bus) in ref[:bus])
        for (i,shunt) in ref[:shunt]
            push!(bus_shunts[shunt["shunt_bus"]], i)
        end
        ref[:bus_shunts] = bus_shunts

        bus_gens = Dict((i, Int64[]) for (i,bus) in ref[:bus])
        for (i,gen) in ref[:gen]
            push!(bus_gens[gen["gen_bus"]], i)
        end
        ref[:bus_gens] = bus_gens

        bus_storage = Dict((i, Int64[]) for (i,bus) in ref[:bus])
        for (i,strg) in ref[:storage]
            push!(bus_storage[strg["storage_bus"]], i)
        end
        ref[:bus_storage] = bus_storage

        bus_arcs = Dict((i, Tuple{Int64,Int64,Int64}[]) for (i,bus) in ref[:bus])
        for (l,i,j) in ref[:arcs]
            push!(bus_arcs[i], (l,i,j))
        end
        ref[:bus_arcs] = bus_arcs

        bus_arcs_dc = Dict((i, Tuple{Int64,Int64,Int64}[]) for (i,bus) in ref[:bus])
        for (l,i,j) in ref[:arcs_dc]
            push!(bus_arcs_dc[i], (l,i,j))
        end
        ref[:bus_arcs_dc] = bus_arcs_dc


        ### reference bus lookup (a set to support multiple connected components) ###
        ref_buses = Dict{Int,Any}()
        for (k,v) in ref[:bus]
            if v["bus_type"] == 3
                ref_buses[k] = v
            end
        end

        ref[:ref_buses] = ref_buses

        if length(ref_buses) > 1
            @warn("multiple reference buses found, $(keys(ref_buses)), this can cause infeasibility if they are in the same connected component")
        end


        ### aggregate info for pairs of connected buses ###
        ref[:buspairs] = PM.buspair_parameters(ref[:arcs_from], ref[:branch], ref[:bus], ref[:conductor_ids], haskey(ref, :conductors))

    end
end


# Model Definitions

""
function build_nip_model(data::Dict{String,Any},
                         model_constructor;
                         multinetwork=true, kwargs...)
    return PM.build_generic_model(data, model_constructor, post_nip; multinetwork=multinetwork, kwargs...)
end

""
function post_nip(pm::PM.GenericPowerModel)
    for (n, network) in PM.nws(pm)
        @assert !PM.ismulticonductor(pm, nw=n)
        PM.variable_voltage(pm, nw=n)
        variable_net_injection(pm, nw=n)
        #PM.variable_branch_flow(pm, nw=n)#, bounded=false)
        #PM.variable_dcline_flow(pm, nw=n)

        PM.constraint_voltage(pm, nw=n)

        for i in PM.ids(pm, :ref_buses, nw=n)
            PM.constraint_theta_ref(pm, i, nw=n)
        end

        for i in PM.ids(pm, :bus, nw=n)
            constraint_kcl_ni(pm, i, nw=n)
        end

        for i in PM.ids(pm, :branch, nw=n)
            PM.constraint_ohms_yt_from(pm, i, nw=n)
            PM.constraint_ohms_yt_to(pm, i, nw=n)

            PM.constraint_voltage_angle_difference(pm, i, nw=n)

            PM.constraint_thermal_limit_from(pm, i, nw=n)
            PM.constraint_thermal_limit_to(pm, i, nw=n)
        end

        for i in PM.ids(pm, :dcline)
            PM.constraint_dcline(pm, i, nw=n)
        end
    end

    return

end


""
function build_nip_expr_model(data::Dict{String,Any}, model_constructor; multinetwork=true, kwargs...)
    return PM.build_generic_model(data, model_constructor, post_nip_expr; multinetwork=multinetwork, kwargs...)
end

""
function post_nip_expr(pm::PM.GenericPowerModel)
    for (n, network) in PM.nws(pm)
        @assert !PM.ismulticonductor(pm, nw=n)
        PM.variable_voltage(pm, nw=n)
        PM.variable_branch_flow(pm, nw=n)#, bounded=false)
        PM.variable_dcline_flow(pm, nw=n)

        PM.constraint_voltage(pm, nw=n)

        for i in PM.ids(pm, :ref_buses, nw=n)
            PM.constraint_theta_ref(pm, i, nw=n)
        end

        for i in PM.ids(pm, :bus, nw=n)
            constraint_kcl_ni_expr(pm, i, nw=n)
        end

        for i in PM.ids(pm, :branch, nw=n)
            PM.constraint_ohms_yt_from(pm, i, nw=n)
            PM.constraint_ohms_yt_to(pm, i, nw=n)

            PM.constraint_voltage_angle_difference(pm, i, nw=n)

            PM.constraint_thermal_limit_from(pm, i, nw=n)
            PM.constraint_thermal_limit_to(pm, i, nw=n)
        end

        for i in PM.ids(pm, :dcline)
            PM.constraint_dcline(pm, i, nw=n)
        end
    end

    return

end


#################################################################################
# Model Extention Functions

"generates variables for both `active` and `reactive` net injection"
function variable_net_injection(pm::PM.GenericPowerModel; kwargs...)
    variable_active_net_injection(pm; kwargs...)
    variable_reactive_net_injection(pm; kwargs...)

    return

end

""
function variable_active_net_injection(pm::PM.GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    PM.var(pm, nw, cnd)[:pni] = JuMP.@variable(pm.model,
        [i in PM.ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_pni",
        start = 0.0
    )

    return

end

""
function variable_reactive_net_injection(pm::PM.GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    PM.var(pm, nw, cnd)[:qni] = JuMP.@variable(pm.model,
        [i in PM.ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_qni",
        start = 0.0
    )

    return
end


""
function constraint_kcl_ni(pm::PM.GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(PM.con(pm, nw, cnd), :kcl_p)
        PM.con(pm, nw, cnd)[:kcl_p] = Dict{Int,JuMP.ConstraintRef}()
    end
    if !haskey(PM.con(pm, nw, cnd), :kcl_q)
        PM.con(pm, nw, cnd)[:kcl_q] = Dict{Int,JuMP.ConstraintRef}()
    end

    bus = PM.ref(pm, nw, :bus, i)
    bus_arcs = PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = PM.ref(pm, nw, :bus_arcs_dc, i)

    constraint_kcl_ni(pm, nw, cnd, i, bus_arcs, bus_arcs_dc)

    return

end


""
function constraint_kcl_ni(pm::PM.GenericPowerModel,
                           n::Int, c::Int, i::Int,
                           bus_arcs, bus_arcs_dc)
    p = PM.var(pm, n, c, :p)
    q = PM.var(pm, n, c, :q)
    pni = PM.var(pm, n, c, :pni, i)
    qni = PM.var(pm, n, c, :qni, i)
    p_dc = PM.var(pm, n, c, :p_dc)
    q_dc = PM.var(pm, n, c, :q_dc)

    PM.con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni)
    PM.con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == qni)

    return

end


""
function constraint_kcl_ni_expr(pm::PM.GenericPowerModel,
                                i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(PM.con(pm, nw, cnd), :kcl_p)
        PM.con(pm, nw, cnd)[:kcl_p] = Dict{Int,JuMP.ConstraintRef}()
    end
    if !haskey(PM.con(pm, nw, cnd), :kcl_q)
        PM.con(pm, nw, cnd)[:kcl_q] = Dict{Int,JuMP.ConstraintRef}()
    end

    bus = PM.ref(pm, nw, :bus, i)
    bus_arcs = PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = PM.ref(pm, nw, :bus_arcs_dc, i)

    pni_expr = PM.ref(pm, nw, :bus, i, "pni")
    qni_expr = PM.ref(pm, nw, :bus, i, "qni")

    constraint_kcl_ni_expr(pm, nw, cnd, i, bus_arcs, bus_arcs_dc, pni_expr, qni_expr)

    return

end


""
function constraint_kcl_ni_expr(pm::PM.GenericPowerModel,
                                n::Int, c::Int, i::Int,
                                bus_arcs, bus_arcs_dc, pni_expr, qni_expr)
    p = PM.var(pm, n, c, :p)
    q = PM.var(pm, n, c, :q)
    p_dc = PM.var(pm, n, c, :p_dc)
    q_dc = PM.var(pm, n, c, :q_dc)

    PM.con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni_expr)
    PM.con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == qni_expr)

    return

end


"active power only models ignore reactive power variables"
function variable_reactive_net_injection(pm::PM.GenericPowerModel{T}; kwargs...) where T <: PM.AbstractDCPForm
    return
end

"active power only models ignore reactive power flows"
function constraint_kcl_ni(pm::PM.GenericPowerModel{T},
                           n::Int, c::Int, i::Int,
                           bus_arcs, bus_arcs_dc) where T <: PM.AbstractDCPForm
    p = PM.var(pm, n, c, :p)
    pni = PM.var(pm, n, c, :pni, i)
    p_dc = PM.var(pm, n, c, :p_dc)

    PM.con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni)

    return

end

""
function constraint_kcl_ni_expr(pm::PM.GenericPowerModel{T},
                                n::Int, c::Int, i::Int,
                                bus_arcs, bus_arcs_dc, pni_expr, qni_expr) where T <: PM.AbstractDCPForm
    p = PM.var(pm, n, c, :p)
    p_dc = PM.var(pm, n, c, :p_dc)

    PM.con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni_expr)

    return

end

""
function powermodels_network!(ps_m::CanonicalModel,
                              system_formulation::Type{S},
                              sys::PSY.System,
                              time_steps::UnitRange{Int64}) where {S <: PM.AbstractPowerFormulation}

    pm_data = pass_to_pm(sys, time_steps[end])
    buses = PSY.get_components(PSY.Bus, sys)

    _remove_undef!(ps_m.expressions[:nodal_balance_active])
    _remove_undef!(ps_m.expressions[:nodal_balance_reactive])

    for t in time_steps, bus in buses
        pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["pni"] = ps_m.expressions[:nodal_balance_active][bus.number,t]
        pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["qni"] = ps_m.expressions[:nodal_balance_reactive][bus.number,t]
    end

    pm_f = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(pm_data, system_formulation; kwargs...)

    ps_m.pm_model = build_nip_expr_model(pm_data, pm_f, jump_model=ps_m.JuMPmodel);

    return

end

""
function powermodels_network!(ps_m::CanonicalModel,
                              system_formulation::Type{S},
                              sys::PSY.System,
                              time_steps::UnitRange{Int64}) where {S <: PM.AbstractActivePowerFormulation}

    pm_data = pass_to_pm(sys, time_steps[end])
    buses = PSY.get_components(PSY.Bus, sys)

    _remove_undef!(ps_m.expressions[:nodal_balance_active])

    for t in time_steps, bus in buses
        pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["pni"] = ps_m.expressions[:nodal_balance_active][bus.number,t]
        #pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["qni"] = 0.0
    end

    pm_f = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, system_formulation; kwargs...)

    ps_m.pm_model = build_nip_expr_model(pm_data, pm_f, jump_model=ps_m.JuMPmodel);

    return

end
