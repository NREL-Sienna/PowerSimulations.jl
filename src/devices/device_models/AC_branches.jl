#Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

struct ACSeriesBranch <: AbstractBranchFormulation end

#Abstract Line Models

abstract type AbstractLineForm <: AbstractBranchFormulation end

struct PiLine <: AbstractLineForm end

#Abstract Transformer Models

abstract type AbstractTransformerForm <: AbstractBranchFormulation end

struct Static2W <: AbstractTransformerForm end

# Not implemented yet
struct TapControl <: AbstractTransformerForm end
struct PhaseControl <: AbstractTransformerForm end

#################################### Branch Variables ##################################################

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_steps::UnitRange{Int64}) where {B <: PSY.ACBranch,
                                                             S <: StandardPTDFForm}

    add_variable(ps_m,
                 devices,
                 time_steps,
                 Symbol("Fbr_$(B)"),
                 false)

    return

end




function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_steps::UnitRange{Int64}) where {B <: PSY.ACBranch,
                                                             S <: PM.AbstractPowerFormulation}
    #Get PowerModels dicts
    pm_object = ps_m.pm_model
    ref = pm_object.ref
    var = pm_object.var
    arc_ix = pm_object.ext[:arc_ix]

    var_name_from_p = Symbol("Pbr_fr_$(B)")
    var_name_to_p = Symbol("Pbr_to_$(B)")
    var_name_from_q = Symbol("Qbr_fr_$(B)")
    var_name_to_q = Symbol("Qbr_to_$(B)")

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
        arc_ix = arc_ix + 1
        bus_fr = d.connectionpoints.from.number
        bus_to = d.connectionpoints.to.number
        arcs_fr = (arc_ix, bus_fr, bus_to)
        arcs_to = (arc_ix, bus_to, bus_fr)

        for t in time_steps
            ref[:nw][t][:branch][arc_ix] = PSI.get_branch_to_pm(arc_ix, d)
            push!(ref[:nw][t][:arcs_from], arcs_fr)
            push!(ref[:nw][t][:arcs_to], arcs_to)
            #careful here the order of the push has to match the order of the variable creation
            push!(ref[:nw][t][:arcs], arcs_fr, arcs_to)

            #Active Power Variables
            ps_m.variables[var_name_from_p][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                            base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                            upper_bound = d.rate,
                                                                            lower_bound = -d.rate,
                                                                            start = 0.0)

            push!(var[:nw][t][:cnd][1][:p], ps_m.variables[var_name_from_p][d.name,t])

            ps_m.variables[var_name_to_p][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                        base_name="$(bus_to),$(bus_fr)_{$(d.name),$(t)}",
                                                                        upper_bound = d.rate,
                                                                        lower_bound = -d.rate,
                                                                        start = 0.0)

            push!(var[:nw][t][:cnd][1][:p], ps_m.variables[var_name_to_p][d.name,t])

            #reactive Power Variables
            ps_m.variables[var_name_from_q][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                        base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                        upper_bound = d.rate,
                                                                        lower_bound = -d.rate,
                                                                        start = 0.0)

            push!(var[:nw][t][:cnd][1][:q], ps_m.variables[var_name_from_q][d.name,t])

            ps_m.variables[var_name_to_q][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                        base_name="$(bus_to),$(bus_fr)_{$(d.name),$(t)}",
                                                                        upper_bound = d.rate,
                                                                        lower_bound = -d.rate,
                                                                        start = 0.0)

            push!(var[:nw][t][:cnd][1][:q], ps_m.variables[var_name_to_q][d.name,t])

        end


    end

    pm_object.ext[:arc_ix] = arc_ix

    return

end

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_steps::UnitRange{Int64}) where {B <: PSY.ACBranch,
                                                             S <: PM.AbstractActivePowerFormulation}

    #Get PowerModels dicts
    pm_object = ps_m.pm_model
    ref = pm_object.ref
    var = pm_object.var
    arc_ix = pm_object.ext[:arc_ix]

    var_name_from_p = Symbol("Pbr_fr_$(B)")
    var_name_to_p = Symbol("Pbr_to_$(B)")

    ps_m.variables[var_name_to_p] = PSI._container_spec(ps_m.JuMPmodel,
                                                       (d.name for d in devices),
                                                       time_steps)

    ps_m.variables[var_name_from_p] = PSI._container_spec(ps_m.JuMPmodel,
                                                          (d.name for d in devices),
                                                          time_steps)

    for (ix, d) in enumerate(devices)
        arc_ix = arc_ix + 1
        bus_fr = d.connectionpoints.from.number
        bus_to = d.connectionpoints.to.number
        arcs_fr = (arc_ix, bus_fr, bus_to)
        arcs_to = (arc_ix, bus_to, bus_fr)

        for t in time_steps
            ref[:nw][t][:branch][arc_ix] = PSI.get_branch_to_pm(arc_ix, d)
            push!(ref[:nw][t][:arcs_from], arcs_fr)
            push!(ref[:nw][t][:arcs_to], arcs_to)
            #careful here the order of the push has to match the order of the variable creation
            push!(ref[:nw][t][:arcs], arcs_fr, arcs_to)

            #Active Power Variables
            ps_m.variables[var_name_from_p][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                            base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                            upper_bound = d.rate,
                                                                            lower_bound = -d.rate,
                                                                            start = 0.0)

            push!(var[:nw][t][:cnd][1][:p], ps_m.variables[var_name_from_p][d.name,t])

            ps_m.variables[var_name_to_p][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                        base_name="$(bus_to),$(bus_fr)_{$(d.name),$(t)}",
                                                                        upper_bound = d.rate,
                                                                        lower_bound = -d.rate,
                                                                        start = 0.0)

            push!(var[:nw][t][:cnd][1][:p], ps_m.variables[var_name_to_p][d.name,t])

        end


    end

    pm_object.ext[:arc_ix] = arc_ix

    return


    return

end


function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_steps::UnitRange{Int64}) where {B <: PSY.ACBranch,
                                                            S <: PM.DCPlosslessForm}

    #Get PowerModels dicts
    pm_object = ps_m.pm_model
    ref = pm_object.ref
    var = pm_object.var
    arc_ix = pm_object.ext[:arc_ix]

    var_name = Symbol("Fbr_$(B)")

    ps_m.variables[var_name] = PSI._container_spec(ps_m.JuMPmodel,
                                                   (d.name for d in devices),
                                                    time_steps)

    for (ix, d) in enumerate(devices)
        arc_ix = arc_ix + 1
        bus_fr = d.connectionpoints.from.number
        bus_to = d.connectionpoints.to.number
        arcs_fr = (arc_ix, bus_fr, bus_to)
        arcs_to = (arc_ix, bus_to, bus_fr)

        for t in time_steps
            ref[:nw][t][:branch][arc_ix] = PSI.get_branch_to_pm(arc_ix, d)
            push!(ref[:nw][t][:arcs_from], arcs_fr)
            push!(ref[:nw][t][:arcs_to], arcs_to)
            #careful here the order of the push has to match the order of the variable creation
            push!(ref[:nw][t][:arcs], arcs_fr, arcs_to)

            #Active Power Variables
            ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                upper_bound = d.rate,
                                                                lower_bound = -d.rate,
                                                                 start = 0.0)

            var[:nw][t][:cnd][1][:p][arcs_fr] = ps_m.variables[var_name][d.name,t]
            var[:nw][t][:cnd][1][:p][arcs_to] = -1*ps_m.variables[var_name][d.name,t]

        end

    end

    pm_object.ext[:arc_ix] = arc_ix

    return


    return

end



#################################### Flow Limits Variables ##################################################

function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{B},
                                device_formulation::Type{D},
                                system_formulation::Type{StandardPTDFForm},
                                time_steps::UnitRange{Int64}) where {B <: PSY.Branch,
                                                                    D <: PM.DCPlosslessForm}

    range_data = [(h.name, (min = -1*h.rate, max = h.rate)) for h in devices]

    device_range(ps_m, range_data, time_steps, Symbol("rate_limit_$(B)"), Symbol("Fbr_$(B)"))

    return

end

#=

####################################Flow Limits using Values ###############################################

####################################Flow Limits using Device ###############################################

function line_flow_limit(ps_m::CanonicalModel,
                         devices::PSY.FlattenedVectorsIterator{B},
                         device_formulation::Type{D},
                         system_formulation::Type{S},
                         time_steps::UnitRange{Int64}) where {B <: PSY.MonitoredLine,
                                                              D <: AbstractBranchFormulation,
                                                              S <: PM.AbstractPowerFormulation}

    return

end

function line_flow_limit(ps_m::CanonicalModel,
                         devices::PSY.FlattenedVectorsIterator{B},
                         device_formulation::Type{D},
                         system_formulation::Type{S},
                         time_steps::UnitRange{Int64}) where {B <: PSY.MonitoredLine,
                                                              D <: AbstractBranchFormulation,
                                                              S <: PM.AbstractActivePowerFormulation}



    return

end

####################################Flow Limits using TimeSeries ###############################################

####################################Flow Limits using Parameters ###############################################

=#