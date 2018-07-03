module PowerSimulations

using JuMP
using TimeSeries
using PowerSystems
using Compat

const PowerVariable = JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}
const PowerExpressionArray = Matrix{<:JuMP.GenericAffExpr}

#utils
include("utils/undef_check.jl")

#base and core
#include("core/abstract_models.jl")
#include("core/dynamic_model.jl")
include("base/node_injections.jl")
#include("base/simulation_constructors.jl")
#include("base/solve_routines.jl")

#Device Modeling components
include("device_models/renewable_generation.jl")
include("device_models/thermal_generation.jl")
include("device_models/storage.jl")
include("device_models/hydro_generation.jl")
include("device_models/electric_loads.jl")
include("device_models/branches.jl")

#Network related components
include("network_models/copperplate_balance.jl")
include("network_models/nodal_balance.jl")

#Cost Components
include("cost_functions/thermalgenvariable_cost.jl")
include("cost_functions/thermalgencommitment_cost.jl")
include("cost_functions/renewablegencurtailment_cost.jl")
include("cost_functions/controlableload_cost.jl")

#PowerModels
#include("power_models/economic_dispatch.jl")

#Utils


end # module
