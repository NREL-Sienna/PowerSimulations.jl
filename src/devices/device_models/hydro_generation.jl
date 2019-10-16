abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end

abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end

struct HydroFixed <: AbstractHydroFormulation end

struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end

struct HydroDispatchSeasonalFlow <: AbstractHydroDispatchFormulation end

struct HydroCommitmentRunOfRiver <: AbstractHydroFormulation end

struct HydroCommitmentSeasonalFlow <: AbstractHydroFormulation end
