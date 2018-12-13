### Thermal Generation Formulations

abstract type AbstractThermalFormulation end

abstract type AbstractThermalDispatchForm <: AbstractThermalFormulation end

abstract type AbstractThermalCommitmentForm <: AbstractThermalFormulation end

struct KenuvenThermalCommitment <: AbstractThermalCommitmentForm end

struct StandardThermalCommitment <: AbstractThermalCommitmentForm end

struct ThermalDispatch <: AbstractThermalDispatchForm end

struct ThermalDispatchNoMin <: AbstractThermalDispatchForm end

struct ThermalRampLimitDispatch <: AbstractThermalDispatchForm end

include("thermal_generation/output_constraints.jl")
include("thermal_generation/ramping_constraints.jl")
include("thermal_generation/thermal_variables.jl")
include("thermal_generation/thermalgencommitment_cost.jl")
include("thermal_generation/thermalgenvariable_cost.jl")
include("thermal_generation/unitcommitment_constraints.jl")