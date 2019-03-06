### Thermal Generation Formulations

abstract type AbstractThermalFormulation <: AbstractDeviceFormulation end

abstract type AbstractThermalDispatchForm <: AbstractThermalFormulation end

struct ThermalUnitCommitment <: AbstractThermalFormulation end

struct ThermalDispatch <: AbstractThermalDispatchForm end

struct ThermalRampLimited <: AbstractThermalDispatchForm end

struct ThermalDispatchNoMin <: AbstractThermalDispatchForm end

include("thermal_generation/thermal_variables.jl")
include("thermal_generation/output_constraints.jl")
include("thermal_generation/unitcommitment_constraints.jl")
include("thermal_generation/ramping_constraints.jl")
include("thermal_generation/time_constraints.jl")
include("thermal_generation/thermalgen_cost.jl")

