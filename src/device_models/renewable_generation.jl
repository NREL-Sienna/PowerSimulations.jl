abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end

abstract type AbstractRenewableDispatchForm <: AbstractRenewableFormulation end

struct RenewableFullDispatch <: AbstractRenewableDispatchForm end

struct RenewableConstantPowerFactor <: AbstractRenewableDispatchForm end

include("renewable_generation/renewable_variables.jl")
include("renewable_generation/output_constraints.jl")
include("renewable_generation/renewablegen_cost.jl")