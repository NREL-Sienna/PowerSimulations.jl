module PowerSimulations

#################################################################################
# Exports

#Network Relevant Exports
export StandardPTDFForm
export CopperPlatePowerModel

#operation_models
export UnitCommitment
export EconomicDispatch
export SCEconomicDispatch
export OptimalPowerFlow

#functions
export solve_op_model!
export demandconstraints


#################################################################################
# Imports
import JuMP
import ParameterJuMP
#using TimeSeries
import PowerSystems
import PowerModels
import MathOptInterface
import DataFrames
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
const PJ = ParameterJuMP

#Type Alias for JuMP and PJ containers
const JuMPExpressionMatrix = Matrix{<:JuMP.AbstractJuMPScalar}
const PGAE{V} = PJ.ParametrizedGenericAffExpr{Float64,V} where V <: JuMP.AbstractVariableRef
const GAE{V} = JuMP.GenericAffExpr{Float64,V} where V <: JuMP.AbstractVariableRef
const JuMPAffineExpressionArray = Matrix{GAE{V}} where V <: JuMP.AbstractVariableRef

#Type Alias for Unions
const FixResource = Union{PSY.RenewableFix, PSY.HydroFix}

#Type Alias for long type signatures
const MinMax = NamedTuple{(:min, :max),Tuple{Float64,Float64}}
const NamedMinMax = Tuple{String, MinMax}
const UpDown = NamedTuple{(:up, :down),Tuple{Float64,Float64}}

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
include("core/device_constructor.jl")
include("core/canonical_constructor.jl")
include("core/operations_constructor.jl")
include("core/core_structs/results_model.jl")
#include("core/core_structs/simulation_model.jl")

#Device Modeling components
include("devices/device_models/common.jl")
include("devices/device_models/renewable_generation.jl")
include("devices/device_models/thermal_generation.jl")
include("devices/device_models/electric_loads.jl")
include("devices/device_models/branches.jl")
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

#Demand Response
include("demand_response/demand_response.jl")
include("demand_response/bev.jl")

#Utils
include("routines/solve_routines.jl")
include("routines/get_ini_cond.jl")
#include("routines/simulation_routines.jl")
#include("routines/device_retreval.jl")

#################################################################################
##### JuMP methods overloading
JuMP.Model(optimizer::Nothing; kwargs...) = JuMP.Model(kwargs...)

#################################################################################

end
