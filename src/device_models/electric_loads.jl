abstract type AbstractLoadForm <: AbstractDeviceFormulation end

abstract type AbstractControllablePowerLoadForm <: AbstractLoadForm end

struct FullControllablePowerLoad <: AbstractControllablePowerLoadForm end

struct InterruptiblePowerLoad <: AbstractControllablePowerLoadForm end

include("electric_loads/load_variables.jl")
include("electric_loads/shedding_constraints.jl")
include("electric_loads/controlableload_cost.jl")