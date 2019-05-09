#Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

struct ACSeriesBranch <: AbstractBranchFormulation end

struct DCSeriesBranch <: AbstractBranchFormulation end

#Abstract Line Models

abstract type AbstractLineForm <: AbstractBranchFormulation end

struct PiLine <: AbstractLineForm end

abstract type AbstractDCLineForm <: AbstractBranchFormulation end

struct HVDC <: AbstractDCLineForm end

struct VoltageSourceDC <: AbstractDCLineForm end

#Abstract Transformer Models

abstract type AbstractTransformerForm <: AbstractBranchFormulation end

struct Static2W <: AbstractTransformerForm end

struct TapControl <: AbstractTransformerForm end

struct PhaseContol <: AbstractTransformerForm end

#################################### Branch Variables ##################################################

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::Array{B,1},
                        time_range::UnitRange{Int64}) where {B <: PSY.Branch,
                                                            S <: PM.DCPlosslessForm}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_$(B)"), 
                 false)

end


function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::Array{B,1},
                        time_range::UnitRange{Int64}) where {B <: PSY.Branch,
                                                             S <: PM.AbstractDCPLLForm}

    add_variable(ps_m, devices, time_range, :Fbr_to, false)
    add_variable(ps_m, devices, time_range, :Fbr_fr, false)

end

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::Array{B,1},
                        time_range::UnitRange{Int64}) where {B <: PSY.Branch,
                                                             S <:PM.AbstractPowerFormulation}

    add_variable(ps_m, devices, time_range, :PFbr_to, false)
    add_variable(ps_m, devices, time_range, :PFbr_fr, false)

    add_variable(ps_m, devices, time_range, :QFbr_to, false)
    add_variable(ps_m, devices, time_range, :QFbr_fr, false)

    return

end

#################################### Flow Limits Variables ##################################################

function line_rate_constraints(ps_m::CanonicalModel,
                               devices::Array{Br,1},
                               device_formulation::Type{D},
                               system_formulation::Type{StandardPTDFForm},
                               time_range::UnitRange{Int64}) where {Br <: PSY.Branch, D <: AbstractBranchFormulation}

    range_data = [(h.name, (min = -1*h.rate, max = h.rate)) for h in devices]

    device_range(ps_m, range_data, time_range, :line_rate_limit, :Fbr)

    return

end

####################################Flow Limits using Values ###############################################

####################################Flow Limits using Device ###############################################

function line_flow_limit(ps_m::CanonicalModel,
                         devices::Array{Br,1},
                         device_formulation::Type{D},
                         system_formulation::Type{S},
                         time_range::UnitRange{Int64}) where {Br <: PSY.MonitoredLine,
                                                               D <: AbstractBranchFormulation,
                                                               S <: PM.AbstractPowerFormulation}

    #rate_data = [(h.name, (min = -1*h.rate, max = h.rate) for h in devices]

    device_range(ps_m, range_data, time_range, :dc_rate_const, :Fbr)

    return

end

function line_flow_limit(ps_m::CanonicalModel,
                         devices::Array{Br,1},
                         device_formulation::Type{D},
                         system_formulation::Type{S},
                         time_range::UnitRange{Int64}) where {Br <: PSY.MonitoredLine,
                                                               D <: AbstractBranchFormulation,
                                                               S <: PM.AbstractActivePowerFormulation}

    #rate_data = [(h.name, (min = -1*h.rate, max = h.rate) for h in devices]

    device_range(ps_m, range_data, time_range, :dc_rate_const, :Fbr)

    return

end

####################################Flow Limits using TimeSeries ###############################################

####################################Flow Limits using Parameters ###############################################