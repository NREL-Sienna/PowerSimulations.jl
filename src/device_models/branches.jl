abstract type AbstractBranchForm end

abstract type AbstractFlowFormulation <: AbstractBranchFormulation end

include("branches/network_flow.jl")
include("branches/dc_powerflow.jl")
