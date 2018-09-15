abstract type AbstractBranchForm end

abstract type AbstractLineForm <: AbstractBranchForm end

abstract type AbstractDCLineForm <: AbstractBranchForm end

abstract type AbstractTransformerForm <: AbstractBranchForm end

abstract type PiLine <: AbstractLineForm end

abstract type SerieLine <: AbstractLineForm end

abstract type SimpleHVDC <: AbstractDCLineForm end

include("branches/flow_variables.jl")
include("branches/bus_variables.jl")
include("branches/flow_constraints.jl")

