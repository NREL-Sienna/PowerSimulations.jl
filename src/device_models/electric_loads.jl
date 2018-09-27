abstract type AbstractLoadForm end

abstract type AbstractControllableLoadForm <: AbstractLoadForm end

struct InterruptibleLoadForm <: AbstractControllableLoadForm end

include("electric_loads/load_variables.jl")
include("electric_loads/shedding_constraints.jl")
include("electric_loads/controlableload_cost.jl")