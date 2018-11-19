abstract type AbstractHydroDispatchForm end

abstract type HydroFullDispatch <: AbstractHydroDispatchForm end

abstract type HydroRunOfRiver <: AbstractHydroDispatchForm end

abstract type HydroSeasonalFlow <: AbstractHydroDispatchForm end

abstract type AbstractHydroCommitmentForm end

abstract type HydroCommitment <: AbstractHydroCommitmentForm end

include("hydro_generation/hydro_variables.jl")
include("hydro_generation/output_constraints.jl")

