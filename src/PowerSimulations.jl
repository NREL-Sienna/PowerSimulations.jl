module PowerSimulations

#################################################################################
# Exports

#Core Exports
export PowerSimulationsModel
export PowerResults

#Base Modeling Exports
export CustomModel
export EconomicDispatch
export UnitCommitment

#Device formulation Export


#Network Relevant Exports
export AbstractDCPowerModel
export CopperPlatePowerModel

#Functions
export buildmodel!
export simulatemodel

#################################################################################
# Imports
using JuMP
using TimeSeries
using PowerSystems
import PowerModels
using Compat
#using GLPK
using MathOptInterface
#using Clp
#using Cbc
#using Ipopt
using DataFrames
using LinearAlgebra

#################################################################################
# Type Alias From other Packages
const PM = PowerModels
const NetworkModel = PM.AbstractPowerFormulation
const PS = PowerSimulations
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities

#Type Alias for JuMP containers
const JumpVariable = JuMP.JuMPArray{JuMP.VariableRef,2,Tuple{Array{String,1},UnitRange{Int64}}}
const JumpExpressionMatrix = Matrix{<:JuMP.GenericAffExpr}
const JumpAffineExpressionArray = Array{JuMP.GenericAffExpr{Float64,JuMP.VariableRef},2}
const BalanceNamedTuple = NamedTuple{(:var_active, :var_reactive, :timeseries_active, :timeseries_reactive),Tuple{JumpAffineExpressionArray, UJ, Array{Float64,2}, UF}} where {UJ <: Union{Nothing,JumpAffineExpressionArray}, UF <: Union{Nothing, Array{Float64,2}}}

#Type Alias for Unions
const fix_resource = Union{PowerSystems.RenewableFix, PowerSystems.HydroFix}


#################################################################################
# Includes

#utils
include("utils/undef_check.jl")
include("utils/cost_addition.jl")
include("utils/timeseries_injections.jl")
include("utils/device_injections.jl")

#Abstract Network Models
include("network_models/networks.jl")

#base and core
include("core/abstract_models.jl")
#include("core/dynamic_model.jl")
include("base/instantiate_routines.jl")
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
include("network_models/copperplate_balance.jl")
include("network_models/nodal_balance.jl")

#Device constructors
include("component_constructors/thermalgeneration_constructor.jl")
include("component_constructors/branch_constructor.jl")
include("component_constructors/renewablegeneration_constructor.jl")
include("component_constructors/services_constructor.jl")

#Network constructors
include("component_constructors/network_constructor.jl")

#Cost Components
include("device_models/electric_loads/controlableload_cost.jl")
include("device_models/renewable_generation/renewablegen_cost.jl")

#PowerModels
#include("power_models/economic_dispatch.jl")

#Utils


end
