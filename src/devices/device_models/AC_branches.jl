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
                                                             S <: PM.AbstractActivePowerFormulation}

    pm_object = ps_m.pm_model
    var_name_from = Symbol("Fbr_fr_$(B)")
    var_name_to = Symbol("Fbr_to_$(B)") 
    ps_m.variables[var_name_to] = _container_spec(ps_m.JuMPmodel, 
                                                  (d.name for d in devices), 
                                                  time_steps)    

    ps_m.variables[var_name_from] = _container_spec(ps_m.JuMPmodel, 
                                                    (d.name for d in devices), 
                                                    time_steps)    

    pm_index = PM.ref(pm_object, 1, :arcs)

    for t in time_steps 
        pm_array = _container_spec(ps_m.JuMPmodel, pm_index)
        for (ix,d) in enumerate(devices)
            ix, d.connectionpoints
            bus_from = d.connectionpoints.from.number
            bus_to = d.connectionpoints.to.number
            pm_array[(ix, bus_from, bus_to)] = ps_m.variables[var_name_from][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                           base_name="$(var_name_from)($(bus_from),$(bus_to))_{$(d.name),$(t)}",
                                                           start = 0.0)
                                                           
            pm_array[(ix, bus_to, bus_from)] = ps_m.variables[var_name_to][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                            base_name="$(var_name_to)($(bus_to),$(bus_from))_{$(d.name),$(t)}",
                                                            start = 0.0)
        end
            PM.var(pm_object, t, 1)[:p] = pm_array
    end                                                        

    return

end

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_steps::UnitRange{Int64}) where {B <: PSY.ACBranch,
                                                             S <: PM.AbstractPowerFormulation}

    add_variable(ps_m,
                 devices,
                 time_steps,
                 Symbol("Fbr_to_P_$(B)"),
                 false)
    add_variable(ps_m,
                 devices,
                 time_steps,
                 Symbol("Fbr_fr_P_$(B)"),
                 false)

    add_variable(ps_m,
                 devices,
                 time_steps,
                 Symbol("Fbr_to_Q_$(B)"),
                 false)
    add_variable(ps_m,
                 devices,
                 time_steps,
                 Symbol("Fbr_fr_Q_$(B)"),
                 false)
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