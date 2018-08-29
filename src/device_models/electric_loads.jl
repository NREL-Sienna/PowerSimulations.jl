abstract type AbstractLoadForm end

abstract type AbstractControllableLoadForm <: AbstractLoadForm end

abstract type InterruptibleLoadForm <: AbstractControllableLoadForm end

include("electric_loads/load_variables.jl")
include("electric_loads/shedding_constraints.jl")