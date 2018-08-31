abstract type AbstractHydroForm end

abstract type HydroCurtailmentForm <: AbstractHydroForm end

include("hydro_generation/hydro_variables.jl")
include("hydro_generation/curtailment_constraints.jl")

