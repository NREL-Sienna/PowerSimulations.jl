abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end

abstract type AbstractHydroDispatchForm <: AbstractHydroFormulation end

abstract type HydroDispatchRunOfRiver <: AbstractHydroDispatchForm end

abstract type HydroDispatchSeasonalFlow <: AbstractHydroDispatchForm end

abstract type HydroCommitmentRunOfRiver <: AbstractHydroFormulation end

abstract type HydroCommitmentSeasonalFlow <: AbstractHydroFormulation end

include("hydro_generation/hydro_variables.jl")
include("hydro_generation/output_constraints.jl")

