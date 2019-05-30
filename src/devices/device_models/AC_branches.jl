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

    var_name = Symbol("Fbr_$(B)")
    ps_m.variables[var_name] = PSI._container_spec(ps_m.JuMPmodel,
                                                    (d.name for d in devices),
                                                     time_steps)

    for (ix, d) in enumerate(devices)
        bus_fr = d.connectionpoints.from.number
        bus_to = d.connectionpoints.to.number
        for t in time_steps
            ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                upper_bound = d.rate,
                                                                lower_bound = -d.rate,
                                                                start = 0.0)
        end
    end
    
    return

end


function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_steps::UnitRange{Int64}) where {B <: PSY.ACBranch,
                                                             S <: PM.AbstractPowerFormulation}
                                                   

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