struct DCSeriesBranch <: AbstractBranchFormulation end

abstract type AbstractDCLineForm <: AbstractBranchFormulation end

struct HVDC <: AbstractDCLineForm end

struct VoltageSourceDC <: AbstractDCLineForm end

#=
function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::Array{B,1},
                        time_steps::UnitRange{Int64}) where {B <: PSY.DCBranch,
                                                             S <: PM.AbstractPowerFormulation}

    add_variable(ps_m,
                 devices,
                 time_steps,
                 Symbol("Fbr_to_$(B)"),
                 false)
    add_variable(ps_m,
                 devices,
                 time_steps,
                 Symbol("Fbr_fr_$(B)"),
                 false)

end
=#

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_steps::UnitRange{Int64}) where {B <: PSY.DCBranch,
                                                             S <: PM.AbstractPowerFormulation}
    #Get PowerModels dicts
    pm_object = ps_m.pm_model
    ref = pm_object.ref
    var = pm_object.var
    dc_arc_ix = pm_object.ext[:dc_arc_ix]

    var_name_from_p = Symbol("PDCbr_fr_$(B)")
    var_name_to_p = Symbol("PDCbr_to_$(B)")
    var_name_from_q = Symbol("QDCbr_fr_$(B)")
    var_name_to_q = Symbol("QDCbr_to_$(B)")

    ps_m.variables[var_name_to_p] = PSI._container_spec(ps_m.JuMPmodel,
                                                       (d.name for d in devices),
                                                       time_steps)

    ps_m.variables[var_name_from_p] = PSI._container_spec(ps_m.JuMPmodel,
                                                          (d.name for d in devices),
                                                          time_steps)


    ps_m.variables[var_name_to_q] = PSI._container_spec(ps_m.JuMPmodel,
                                                       (d.name for d in devices),
                                                       time_steps)

    ps_m.variables[var_name_from_q] = PSI._container_spec(ps_m.JuMPmodel,
                                                          (d.name for d in devices),
                                                          time_steps)


    for (ix, d) in enumerate(devices)
        dc_arc_ix = dc_arc_ix + 1
        bus_fr = d.connectionpoints.from.number
        bus_to = d.connectionpoints.to.number
        arcs_fr = (dc_arc_ix, bus_fr, bus_to)
        arcs_to = (dc_arc_ix, bus_to, bus_fr)

        for t in time_steps
            ref[:nw][t][:dcline][dc_arc_ix] = PSI.get_branch_to_pm(dc_arc_ix, d)
            push!(ref[:nw][t][:arcs_from_dc], arcs_fr)
            push!(ref[:nw][t][:arcs_to_dc], arcs_to)
            #careful here the order of the push has to match the order of the variable creation
            push!(ref[:nw][t][:arcs_dc], arcs_fr, arcs_to)

            #Active Power Variables
            ps_m.variables[var_name_from_p][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                            base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                            upper_bound = d.rate,
                                                                            lower_bound = -d.rate,
                                                                            start = 0.0)

            push!(var[:nw][t][:cnd][1][:P], ps_m.variables[var_name_from_p][d.name,t])

            ps_m.variables[var_name_to_p][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                        base_name="$(bus_to),$(bus_fr)_{$(d.name),$(t)}",
                                                                        upper_bound = d.rate,
                                                                        lower_bound = -d.rate,
                                                                        start = 0.0)

            push!(var[:nw][t][:cnd][1][:P], ps_m.variables[var_name_to_p][d.name,t])

            #reactive Power Variables
            ps_m.variables[var_name_from_q][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                        base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                        upper_bound = d.rate,
                                                                        lower_bound = -d.rate,
                                                                        start = 0.0)

            push!(var[:nw][t][:cnd][1][:q_dc], ps_m.variables[var_name_from_q][d.name,t])

            ps_m.variables[var_name_to_q][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                        base_name="$(bus_to),$(bus_fr)_{$(d.name),$(t)}",
                                                                        upper_bound = d.rate,
                                                                        lower_bound = -d.rate,
                                                                        start = 0.0)

            push!(var[:nw][t][:cnd][1][:q_dc], ps_m.variables[var_name_to_q][d.name,t])

        end


    end

    pm_object.ext[:dc_arc_ix] = dc_arc_ix

    return

end

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_steps::UnitRange{Int64}) where {B <: PSY.DCBranch,
                                                             S <: PM.AbstractActivePowerFormulation}

    #Get PowerModels dicts
    pm_object = ps_m.pm_model
    ref = pm_object.ref
    var = pm_object.var
    dc_arc_ix = pm_object.ext[:dc_arc_ix]

    var_name_from_p = Symbol("PDCbr_fr_$(B)")
    var_name_to_p = Symbol("PDCbr_to_$(B)")

    ps_m.variables[var_name_to_p] = PSI._container_spec(ps_m.JuMPmodel,
                                                       (d.name for d in devices),
                                                       time_steps)

    ps_m.variables[var_name_from_p] = PSI._container_spec(ps_m.JuMPmodel,
                                                          (d.name for d in devices),
                                                          time_steps)

    for (ix, d) in enumerate(devices)
        dc_arc_ix = dc_arc_ix + 1
        bus_fr = d.connectionpoints.from.number
        bus_to = d.connectionpoints.to.number
        arcs_fr = (dc_arc_ix, bus_fr, bus_to)
        arcs_to = (dc_arc_ix, bus_to, bus_fr)

        for t in time_steps
            ref[:nw][t][:dcline][dc_arc_ix] = PSI.get_branch_to_pm(dc_arc_ix, d)
            push!(ref[:nw][t][:arcs_from_dc], arcs_fr)
            push!(ref[:nw][t][:arcs_to_dc], arcs_to)
            #careful here the order of the push has to match the order of the variable creation
            push!(ref[:nw][t][:arcs_dc], arcs_fr, arcs_to)

            #Active Power Variables
            ps_m.variables[var_name_from_p][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                            base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                            upper_bound = d.rate,
                                                                            lower_bound = -d.rate,
                                                                            start = 0.0)

            push!(var[:nw][t][:cnd][1][:P], ps_m.variables[var_name_from_p][d.name,t])

            ps_m.variables[var_name_to_p][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                        base_name="$(bus_to),$(bus_fr)_{$(d.name),$(t)}",
                                                                        upper_bound = d.rate,
                                                                        lower_bound = -d.rate,
                                                                        start = 0.0)

            push!(var[:nw][t][:cnd][1][:P], ps_m.variables[var_name_to_p][d.name,t])

        end


    end

    pm_object.ext[:dc_arc_ix] = dc_arc_ix

    return


    return

end


function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_steps::UnitRange{Int64}) where {B <: PSY.DCBranch,
                                                            S <: PM.DCPlosslessForm}

    #Get PowerModels dicts
    pm_object = ps_m.pm_model
    ref = pm_object.ref
    var = pm_object.var
    dc_arc_ix = pm_object.ext[:dc_arc_ix]

    var_name = Symbol("DCbr_$(B)")

    ps_m.variables[var_name] = PSI._container_spec(ps_m.JuMPmodel,
                                                   (d.name for d in devices),
                                                    time_steps)

    for (ix, d) in enumerate(devices)
        dc_arc_ix = dc_arc_ix + 1
        bus_fr = d.connectionpoints.from.number
        bus_to = d.connectionpoints.to.number
        arcs_fr = (dc_arc_ix, bus_fr, bus_to)
        arcs_to = (dc_arc_ix, bus_to, bus_fr)

        for t in time_steps
            ref[:nw][t][:dcline][dc_arc_ix] = PSI.get_branch_to_pm(dc_arc_ix, d)
            push!(ref[:nw][t][:arcs_from_dc], arcs_fr)
            push!(ref[:nw][t][:arcs_to_dc], arcs_to)
            #careful here the order of the push has to match the order of the variable creation
            push!(ref[:nw][t][:arcs_dc], arcs_fr, arcs_to)

            #Active Power Variables
            ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                upper_bound = d.rate,
                                                                lower_bound = -d.rate,
                                                                 start = 0.0)

            var[:nw][t][:cnd][1][:P][arcs_fr] = ps_m.variables[var_name][d.name,t]
            var[:nw][t][:cnd][1][:P][arcs_to] = -1*ps_m.variables[var_name][d.name,t]

        end

    end

    pm_object.ext[:dc_arc_ix] = dc_arc_ix

    return


    return

end