module PowerSimulations

#################################################################################
# Exports

# Base Models
export Stage
export Simulation
export OperationModel
export ModelReference
export InitialCondition

#Network Relevant Exports
export StandardPTDFForm
export CopperPlatePowerModel

######## Device Models ########
export DeviceModel
######## Branche Models ########
export StaticLine
export StaticTransformer
export TapControl
#export PhaseControl
export HVDCLossless
export HVDCDispatch
#export VoltageSourceDC
######## Load Models ########
export StaticPowerLoad
export InterruptiblePowerLoad
export DispatchablePowerLoad
######## Renewable Formulations ########
export RenewableFixed
export RenewableFullDispatch
export RenewableConstantPowerFactor
######## Hydro Formulations ########
export HydroFixed
######## Renewable Formulations ########
export BookKeeping
export BookKeepingwReservation
######## Thermal Formulations ########
export ThermalUnitCommitment
export ThermalDispatch
export ThermalRampLimited
export ThermalDispatchNoMin

# Feedback Models
export RecedingHorizon
export Synchronize

#operation_models
#export UnitCommitment
#export EconomicDispatch
#export OptimalPowerFlow

# Functions
## Construction Exports
export construct_device!
export construct_network!
## Op Model Exports
export solve_op_model!
## Sim Model Exports
export run_sim_model!
## Utils Exports
export write_model_result
export get_all_constraint_index
export get_all_var_index
export get_con_index
export get_var_index


#################################################################################
# Imports
#Modeling Imports
import JuMP
# so that users do not need to import JuMP to use a solver with PowerModels
import JuMP: with_optimizer
export with_optimizer
import MathOptInterface
import ParameterJuMP
import LinearAlgebra
import PowerSystems
import PowerModels

#TimeStamp Management Imports
import Dates
import TimeSeries

#I/O Imports
import MathOptFormat
import DataFrames
import Feather


#################################################################################
#Type Alias for long type signatures
const MinMax = NamedTuple{(:min, :max), NTuple{2, Float64}}
const NamedMinMax = Tuple{String, MinMax}
const UpDown = NamedTuple{(:up, :down), NTuple{2, Float64}}
const InOut = NamedTuple{(:in, :out), NTuple{2, Float64}}

# Type Alias From other Packages
const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities
const PJ = ParameterJuMP
const MOPFM = MathOptFormat.MOF.Model()

#Type Alias for JuMP and PJ containers
const JuMPExpressionMatrix = Matrix{<:JuMP.AbstractJuMPScalar}
const PGAE{V} = PJ.ParametrizedGenericAffExpr{Float64, V} where V<:JuMP.AbstractVariableRef
const GAE{V} = JuMP.GenericAffExpr{Float64, V} where V<:JuMP.AbstractVariableRef
const JuMPAffineExpressionArray = Matrix{GAE{V}} where V<:JuMP.AbstractVariableRef
const JuMPConstraintArray = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}
const JuMPParamArray = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}

#################################################################################
##### JuMP methods overloading
JuMP.Model(optimizer::Nothing; kwargs...) = JuMP.Model(kwargs...)

#################################################################################

#################################################################################
# Includes

#Abstract Models
include("network_models/networks.jl")
include("service_models/services.jl")

#Core Models and constructors
include("core/core_structs/device_model.jl")
include("core/core_structs/canonical_model.jl")
include("core/core_structs/service_model.jl")
include("core/core_structs/operation_model.jl")
include("core/core_structs/simulation_model.jl")
include("core/core_structs/results_model.jl")
include("core/build_operations.jl")
include("core/build_simulations.jl")

#Device Modeling components
include("devices/device_models/common.jl")
include("devices/device_models/renewable_generation.jl")
include("devices/device_models/thermal_generation.jl")
include("devices/device_models/electric_loads.jl")
include("devices/device_models/AC_branches.jl")
include("devices/device_models/DC_branches.jl")
include("devices/device_models/storage.jl")
include("devices/device_models/hydro_generation.jl")

#Network models
include("network_models/copperplate_model.jl")
include("network_models/powermodels_interface.jl")
include("network_models/ptdf_model.jl")

#Device constructors
include("devices/device_constructors/device_constructors.jl")

#Network constructors
include("network_models/network_constructor.jl")

#Services Models
#include("service_models/reserves.jl")

#Services constructors
include("service_models/services_constructor.jl")

#Operational Model Constructors
include("operation_models/operation_models.jl")

#Simulations Model Files
include("simulation_models/stage_update.jl")

#Routines
include("routines/get_results.jl")
include("routines/solve_routines.jl")

#Utils
include("utils/optimization_debugging.jl")
include("utils/write_model.jl")
include("utils/printing.jl")

end
