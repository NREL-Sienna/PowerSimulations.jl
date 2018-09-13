abstract type AbstractHydroFormulation end

abstract type HydroCurtailmentForm <: AbstractHydroFormulation end

include("hydro_generation/hydro_variables.jl")
include("hydro_generation/curtailment_constraints.jl")

