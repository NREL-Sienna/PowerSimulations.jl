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
                        time_range::UnitRange{Int64}) where {B <: PSY.ACBranch,
                                                             S <: PM.DCPlosslessForm}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_$(B)"), 
                 false)

end


function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_range::UnitRange{Int64}) where {B <: PSY.ACBranch,
                                                             S <: PM.AbstractDCPLLForm}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_to_$(B)"), 
                 false)
    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_fr_$(B)"),  
                 false)

end

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B},
                        time_range::UnitRange{Int64}) where {B <: PSY.ACBranch,
                                                             S <: PM.AbstractPowerFormulation}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_to_P_$(B)"), 
                 false)
    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_fr_P_$(B)"),  
                 false)

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_to_Q_$(B)"), 
                 false)
    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_fr_Q_$(B)"),  
                 false)                 
    return

end

#################################### Flow Limits Variables ##################################################

function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{B},
                                device_formulation::Type{D},
                                system_formulation::Type{StandardPTDFForm},
                                time_range::UnitRange{Int64}) where {B <: PSY.Branch, 
                                                                    D <: PM.DCPlosslessForm}

    range_data = [(h.name, (min = -1*h.rate, max = h.rate)) for h in devices]

    device_range(ps_m, range_data, time_range, Symbol("rate_limit_$(B)"), Symbol("Fbr_$(B)"))

    return

end

#=

####################################Flow Limits using Values ###############################################

####################################Flow Limits using Device ###############################################

function line_flow_limit(ps_m::CanonicalModel,
                         devices::PSY.FlattenedVectorsIterator{B},
                         device_formulation::Type{D},
                         system_formulation::Type{S},
                         time_range::UnitRange{Int64}) where {B <: PSY.MonitoredLine,
                                                              D <: AbstractBranchFormulation,
                                                              S <: PM.AbstractPowerFormulation}

    return

end

function line_flow_limit(ps_m::CanonicalModel,
                         devices::PSY.FlattenedVectorsIterator{B},
                         device_formulation::Type{D},
                         system_formulation::Type{S},
                         time_range::UnitRange{Int64}) where {B <: PSY.MonitoredLine,
                                                              D <: AbstractBranchFormulation,
                                                              S <: PM.AbstractActivePowerFormulation}

    

    return

end

####################################Flow Limits using TimeSeries ###############################################

####################################Flow Limits using Parameters ###############################################

=#