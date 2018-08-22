module PowerSimulations

#################################################################################
# Exports

#Device Relevant Exports
export powerconstraints
export commitmentconstraints
export rampconstraints
export timeconstraints

export curtailconstraints

#Network Relevant Exports
export Network
export CopperPlate
export NetworkFlow
export DCPowerFlow
export ACPowerFlow
export flowconstraints


#Functions
export buildmodel!
export simulatemodel

#################################################################################
# Imports
using JuMP
using TimeSeries
using PowerSystems
using Compat
using Clp
using Cbc
#using Ipopt
using DataFrames
using LinearAlgebra

#################################################################################
# Type Alias

const JumpVariable = JuMP.JuMPArray{JuMP.VariableRef,2,Tuple{Array{String,1},UnitRange{Int64}}}
const JumpExpressionMatrix = Matrix{<:JuMP.GenericAffExpr}

# TODO: this syntax might change with JuMP 0.19
const JumpAffineExpressionArray = Array{JuMP.GenericAffExpr{Float64,JuMP.VariableRef},2}

#################################################################################
# Includes

#utils
include("utils/undef_check.jl")

#base and core
include("core/abstract_models.jl")
#include("core/dynamic_model.jl")
include("base/device_injections.jl")
include("base/timeseries_injections.jl")
include("base/model_constructors.jl")
include("base/simulation_routines.jl")
include("base/solve_routines.jl")

#Device Modeling components
include("device_models/renewable_generation.jl")
include("device_models/thermal_generation.jl")
include("device_models/storage.jl")
include("device_models/hydro_generation.jl")
include("device_models/electric_loads.jl")
include("device_models/branches.jl")

#Network related components
include("network_models/networks.jl")
include("network_models/copperplate_balance.jl")
include("network_models/nodal_balance.jl")

#Device constructors
include("component_constructors/thermalgeneration_constructor.jl")
include("component_constructors/renewablegeneration_constructor.jl")
include("component_constructors/services_constructor.jl")

#Network constructors
include("component_constructors/network_constructor.jl")

#Cost Components
include("cost_functions/controlableload_cost.jl")
include("cost_functions/renewablegen_cost.jl")
include("cost_functions/thermalgenvariable_cost.jl")
include("cost_functions/thermalgencommitment_cost.jl")

#PowerModels
#include("power_models/economic_dispatch.jl")

#Utils


end # module
