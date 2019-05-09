abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

abstract type AbstractLineForm <: AbstractBranchFormulation end

abstract type AbstractDCLineForm <: AbstractBranchFormulation end

abstract type AbstractTransformerForm <: AbstractBranchFormulation end

abstract type PiLine <: AbstractLineForm end

abstract type SeriesLine <: AbstractLineForm end

abstract type SimpleHVDC <: AbstractDCLineForm end

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


function line_rate_constraints(ps_m::CanonicalModel,
                               devices::Array{Br,1},
                               device_formulation::Type{D},
                                system_formulation::Type{StandardPTDFForm},
                          time_range::UnitRange{Int64}) where {Br <: PSY.Branch, D <: AbstractBranchFormulation}

    range_data = [(h.name, (min = -1*h.rate, max = h.rate)) for h in devices]

    device_range(ps_m, range_data, time_range, :line_rate_limit, :Fbr)

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

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::Array{B,1},
                        time_range::UnitRange{Int64}) where {B <: PSY.Branch,
                                                            S <: PM.DCPlosslessForm}

    add_variable(ps_m, devices, time_range, :Fbr, false)

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

