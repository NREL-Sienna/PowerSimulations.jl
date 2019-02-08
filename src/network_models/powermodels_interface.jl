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
# Model Definitions

""
function build_nip_model(data::Dict{String,Any}, model_constructor; multinetwork=true, kwargs...)
    return PM.build_generic_model(data, model_constructor, post_nip; multinetwork=multinetwork, kwargs...)
end

""
function post_nip(pm::PM.GenericPowerModel)
    for (n, network) in PM.nws(pm)
        @assert !PM.ismulticonductor(pm, nw=n)
        PM.variable_voltage(pm, nw=n)
        variable_net_injection(pm, nw=n)
        PM.variable_branch_flow(pm, nw=n)#, bounded=false)
        PM.variable_dcline_flow(pm, nw=n)

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
end


#################################################################################
# Model Extention Functions

"generates variables for both `active` and `reactive` net injection"
function variable_net_injection(pm::PM.GenericPowerModel; kwargs...)
    variable_active_net_injection(pm; kwargs...)
    variable_reactive_net_injection(pm; kwargs...)
end

""
function variable_active_net_injection(pm::PM.GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    PM.var(pm, nw, cnd)[:pni] = JuMP.@variable(pm.model,
        [i in PM.ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_pni",
        start = 0.0
    )
end

""
function variable_reactive_net_injection(pm::PM.GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    PM.var(pm, nw, cnd)[:qni] = JuMP.@variable(pm.model,
        [i in PM.ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_qni",
        start = 0.0
    )
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
end


""
function constraint_kcl_ni(pm::PM.GenericPowerModel, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc)
    p = PM.var(pm, n, c, :p)
    q = PM.var(pm, n, c, :q)
    pni = PM.var(pm, n, c, :pni, i)
    qni = PM.var(pm, n, c, :qni, i)
    p_dc = PM.var(pm, n, c, :p_dc)
    q_dc = PM.var(pm, n, c, :q_dc)

    PM.con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni)
    PM.con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == qni)
end


""
function constraint_kcl_ni_expr(pm::PM.GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
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
end


""
function constraint_kcl_ni_expr(pm::PM.GenericPowerModel, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, pni_expr, qni_expr)
    p = PM.var(pm, n, c, :p)
    q = PM.var(pm, n, c, :q)
    p_dc = PM.var(pm, n, c, :p_dc)
    q_dc = PM.var(pm, n, c, :q_dc)

    PM.con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni_expr)
    PM.con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == qni_expr)
end


"active power only models ignore reactive power variables"
function variable_reactive_net_injection(pm::PM.GenericPowerModel{T}; kwargs...) where T <: PM.AbstractDCPForm
end

"active power only models ignore reactive power flows"
function constraint_kcl_ni(pm::PM.GenericPowerModel{T}, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc) where T <: PM.AbstractDCPForm
    p = PM.var(pm, n, c, :p)
    pni = PM.var(pm, n, c, :pni, i)
    p_dc = PM.var(pm, n, c, :p_dc)

    PM.con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni)
end

""
function constraint_kcl_ni_expr(pm::PM.GenericPowerModel{T}, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, pni_expr, qni_expr) where T <: PM.AbstractDCPForm
    p = PM.var(pm, n, c, :p)
    p_dc = PM.var(pm, n, c, :p_dc)

    PM.con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni_expr)
end

""
function powermodels_network!(ps_m::CanonicalModel, system_formulation::Type{S}, sys::PSY.PowerSystem, time_range::UnitRange{Int64}) where {S <: PM.AbstractPowerFormulation}

    pm_data = pass_to_pm(sys)

    for t in time_range, bus in sys.buses

        pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["pni"] = ps_m.expressions["var_active"][bus.number,t]
        pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["qni"] = ps_m.expressions["var_reactive"][bus.number,t]

    end

    pm_f = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(pm_data, system_formulation; kwargs...)

    ps_m.pm_model = PSI.build_nip_expr_model(pm_data, pm_f, jump_model=ps_m.JuMPmodel);

end

""
function powermodels_network!(ps_m::CanonicalModel, system_formulation::Type{S}, sys::PSY.PowerSystem, time_range::UnitRange{Int64}) where {S <: PM.AbstractActivePowerFormulation}

    pm_data = pass_to_pm(sys)

    for t in time_range, bus in sys.buses

        pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["pni"] = ps_m.expressions["var_active"][bus.number,t]
        #pm_data["nw"]["$(t)"]["bus"]["$(bus.number)"]["qni"] = 0.0

    end

    pm_f = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, system_formulation; kwargs...)

    ps_m.pm_model = PSI.build_nip_expr_model(pm_data, pm_f, jump_model=ps_m.JuMPmodel);

end