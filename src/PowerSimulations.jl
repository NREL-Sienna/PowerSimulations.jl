module PowerSimulations

#################################################################################
# Exports

# Base Models
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

#operation_models
#export UnitCommitment
#export EconomicDispatch
#export OptimalPowerFlow

#functions
export construct_device!
export construct_network!
export solve_op_model!


#################################################################################
# Imports
import JuMP
import ParameterJuMP
import TimeSeries
import PowerSystems
import PowerModels
import MathOptInterface
import DataFrames
import LinearAlgebra
#import LinearAlgebra.BLAS #needed for the simulation stage
import Dates

# so that users do not need to import JuMP to use a solver with PowerModels
import JuMP: with_optimizer
export with_optimizer

#################################################################################
# Type Alias From other Packages
const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities
const PJ = ParameterJuMP

#Type Alias for JuMP and PJ containers
const JuMPExpressionMatrix = Matrix{<:JuMP.AbstractJuMPScalar}
const PGAE{V} = PJ.ParametrizedGenericAffExpr{Float64, V} where V <: JuMP.AbstractVariableRef
const GAE{V} = JuMP.GenericAffExpr{Float64, V} where V <: JuMP.AbstractVariableRef
const JuMPAffineExpressionArray = Matrix{GAE{V}} where V <: JuMP.AbstractVariableRef
const JuMPConstraintArray = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}
const JuMPParamArray = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}

#Type Alias for long type signatures
const MinMax = NamedTuple{(:min, :max), NTuple{2, Float64}}
const NamedMinMax = Tuple{String, MinMax}
const UpDown = NamedTuple{(:up, :down), NTuple{2, Float64}}
const InOut = NamedTuple{(:in, :out), NTuple{2, Float64}}

#################################################################################
# Includes

#Abstract Models
include("network/network_models/networks.jl")
include("services/service_models/services.jl")

#Core Models and constructors
include("core/core_structs/device_model.jl")
include("core/core_structs/canonical_model.jl")
include("core/core_structs/service_model.jl")
include("core/core_structs/operation_model.jl")
include("core/core_structs/simulation_model.jl")
include("core/device_constructor.jl")
include("core/canonical_constructor.jl")
include("core/operations_constructor.jl")
include("core/core_structs/results_model.jl")
include("core/simulation_constructor.jl")

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
include("network/network_models/copperplate_model.jl")
include("network/network_models/powermodels_interface.jl")
include("network/network_models/ptdf_model.jl")

#Device constructors
include("devices/device_constructors/device_constructors.jl")

#Network constructors
include("network/network_constructor.jl")

#Services Models
#include("service_models/reserves.jl")

#Services constructors
include("services/services_constructor.jl")

#Operational Model Constructors
include("operation_models/operation_models.jl")

#Utils
include("routines/printing.jl")
include("routines/solve_routines.jl")
include("routines/get_ini_cond.jl")
include("routines/optimization_debugging.jl")
include("routines/simulation_routines.jl")

#################################################################################
##### JuMP methods overloading
JuMP.Model(optimizer::Nothing; kwargs...) = JuMP.Model(kwargs...)

#################################################################################

end
