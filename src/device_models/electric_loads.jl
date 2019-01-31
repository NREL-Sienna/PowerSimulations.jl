abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end

abstract type AbstractControllablePowerLoadForm <: AbstractLoadFormulation end

struct StaticPowerLoad <: AbstractLoadFormulation end

struct InterruptiblePowerLoad <: AbstractControllablePowerLoadForm end

include("electric_loads/load_variables.jl")
include("electric_loads/shedding_constraints.jl")
include("electric_loads/controlableload_cost.jl")