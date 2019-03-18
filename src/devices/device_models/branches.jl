abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

abstract type AbstractLineForm <: AbstractBranchFormulation end

abstract type AbstractDCLineForm <: AbstractBranchFormulation end

abstract type AbstractTransformerForm <: AbstractBranchFormulation end

abstract type PiLine <: AbstractLineForm end

abstract type SeriesLine <: AbstractLineForm end

abstract type SimpleHVDC <: AbstractDCLineForm end

include("branches/flow_variables.jl")
include("branches/rate_constraints.jl")
include("branches/flow_constraints.jl")