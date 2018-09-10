### Thermal Generation Formulations

abstract type AbstractThermalFormulation end

abstract type AbstractThermalDispatchForm <: AbstractThermalFormulation end

abstract type AbstractThermalCommitmentForm <: AbstractThermalFormulation end

abstract type KenuvenThermalCommitment <: AbstractThermalCommitmentForm end

abstract type StandardThermalCommitment <: AbstractThermalCommitmentForm end

abstract type Dispatch <: AbstractThermalDispatchForm end

abstract type RampLimitDispatch <: AbstractThermalDispatchForm end

include("thermal_generation/thermal_variables.jl")
include("thermal_generation/output_constraints.jl")
include("thermal_generation/ramping_constraints.jl")
include("thermal_generation/unitcommitment_constraints.jl")