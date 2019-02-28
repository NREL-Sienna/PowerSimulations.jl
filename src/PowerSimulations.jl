module PowerSimulations

#################################################################################
# Exports

#Core Exports
#export PowerSimulationsModel
#export PowerResults

#Base Modeling Exports
#export CustomModel
#export EconomicDispatch
#export UnitCommitment

#Network Relevant Exports
export StandardPTDFModel
export CopperPlatePowerModel

#Functions
export buildmodel!
export simulatemodel

#################################################################################
# Imports
import JuMP
#using TimeSeries
import PowerSystems
import PowerModels
import MathOptInterface
#import DataFrames #Needed to display results
import LinearAlgebra
#import LinearAlgebra.BLAS #needed for the simulation stage
import AxisArrays
import Dates

#################################################################################
# Type Alias From other Packages
const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities

#Type Alias for JuMP containers
const JumpExpressionMatrix = Matrix{<:JuMP.GenericAffExpr}
const JumpAffineExpressionArray = Array{JuMP.GenericAffExpr{Float64,JuMP.VariableRef},2}

#Type Alias for Unions
const FixResource = Union{PSY.RenewableFix, PSY.HydroFix}

#################################################################################
# Includes

#Abstract Models
include("network_models/networks.jl")
include("service_models/services.jl")

#Core Models
include("abstract_models/canonical_model.jl")
include("abstract_models/device_model.jl")
include("abstract_models/operation_model.jl")
#include("abstract_models/simulation_model.jl")
#include("abstract_models/results_model.jl")

#Core Constructors
#include("operations_constructor.jl")

#Device Modeling components
include("device_models/common.jl")
include("device_models/renewable_generation.jl")
include("device_models/thermal_generation.jl")
include("device_models/electric_loads.jl")
include("device_models/branches.jl")
include("device_models/storage.jl")
include("device_models/hydro_generation.jl")

#Network models
include("network_models/copperplate_model.jl")
include("network_models/powermodels_interface.jl")
include("network_models/ptdf_model.jl")

#Device constructors
include("device_constructors/thermalgeneration_constructor.jl")
include("device_constructors/branch_constructor.jl")
include("device_constructors/renewablegeneration_constructor.jl")
include("device_constructors/load_constructor.jl")
include("device_constructors/storage_constructor.jl")

#Network constructors
include("network_constructor.jl")

#Services Models
#include("service_models/reserves.jl")

#Services constructors
#include("services_constructor.jl")

#Operational Models
include("operation_models/operation_models.jl")

#Utils
#include("routines/solve_routines.jl")
#include("routines/simulation_routines.jl")
#include("routines/device_retreval.jl")


end
