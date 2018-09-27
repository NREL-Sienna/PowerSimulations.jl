abstract type AbstractRenewableFormulation end

abstract type AbstractRenewableDispatchForm <: AbstractRenewableFormulation end

struct RenewableCurtail <: AbstractRenewableDispatchForm end

struct RenewableCapacityCurve <: AbstractRenewableDispatchForm end

include("renewable_generation/renewable_variables.jl")
include("renewable_generation/output_constraints.jl")
include("renewable_generation/renewablegen_cost.jl")