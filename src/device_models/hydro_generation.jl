abstract type AbstractHydroDispatchForm end

abstract type HydroCurtailment <: AbstractHydroDispatchForm end

include("hydro_generation/hydro_variables.jl")
include("hydro_generation/output_constraints.jl")

