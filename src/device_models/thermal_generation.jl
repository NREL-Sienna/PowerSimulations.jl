### Thermal Generation Formulations

abstract type AbstractThermalFormulation end

abstract type AbstractDispatchForm <: AbstractThermalFormulation end

abstract type AbstractUnitCommitmentForm <: AbstractThermalFormulation end

abstract type KenuvenUnitCommitment <: AbstractUnitCommitmentForm end

abstract type StandardUnitCommitment <: AbstractUnitCommitmentForm end

abstract type Dispatch <: AbstractDispatchForm end

abstract type RampingDispatch <: AbstractDispatchForm end

include("thermal_generation/thermal_variables.jl")
include("thermal_generation/output_constraints.jl")
include("thermal_generation/ramping_constraints.jl")
include("thermal_generation/unitcommitment_constraints.jl")