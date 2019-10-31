module PowerSimulations

#################################################################################
# Exports

# Base Models
export Stage
export Simulation
export OperationsProblem
export FormulationTemplate
export InitialCondition

#Network Relevant Exports
export StandardPTDFModel
export CopperPlatePowerModel

######## Device Models ########
export DeviceModel
######## Service Models ########
export ServiceModel
######## Branch Models ########
export StaticLine
export StaticTransformer
export TapControl
export StaticLineUnbounded
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
export ThermalStandardUnitCommitment
export ThermalBasicUnitCommitment
export ThermalDispatch
export ThermalRampLimited
export ThermalDispatchNoMin

# feedforward sequences
export RecedingHorizon
export Synchronize
export Sequential

# feedforward models
export UpperBoundFF
export SemiContinuousFF
export RangeFF

# Initial Conditions Quantities
export DevicePower
export DeviceStatus
export TimeDurationON
export TimeDurationOFF
export DeviceEnergy

# cache_models
export TimeStatusChange

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
export get_initial_conditions
export set_transmission_ref!
export set_devices_ref!
export set_branches_ref!
export set_services_ref!
export set_device_model!
export set_branch_model!
export set_device_model!
## Sim Model Exports
export run_sim_model!
## Utils Exports
export write_op_model
export write_model_results
export load_operation_results
export get_all_constraint_index
export get_all_var_index
export get_con_index
export get_var_index
# Plotting Utils
export sort_data
export get_stacked_plot_data
export get_bar_plot_data
export get_stacked_generation_data
export bar_plot
export stack_plot
export report
export load_simulation_results

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
import InfrastructureSystems
import PowerModels
import RecipesBase
import Requires

#TimeStamp Management Imports
import Dates
import TimeSeries

#I/O Imports
import MathOptFormat
import DataFrames
import Feather

include("core/definitions.jl")

#################################################################################
##### JuMP methods overloading
JuMP.Model(optimizer::Nothing; kwargs...) = JuMP.Model(kwargs...)

################################################################################
# Includes

#Abstract Models
include("network_models/networks.jl")
include("service_models/services.jl")

#Core Models and constructors
include("core/core_structs/aux_structs.jl")
include("core/core_structs/cache_models.jl")
include("core/core_structs/feedforward_model.jl")
include("core/core_structs/device_model.jl")
include("core/core_structs/initial_conditions.jl")
include("core/core_structs/canonical.jl")
include("core/core_structs/service_model.jl")
include("core/core_structs/operation_model.jl")
include("core/core_structs/chronology.jl")
include("core/core_structs/simulations_stages.jl")
include("core/core_structs/simulation_model.jl")
include("core/core_structs/results_model.jl")
include("core/build_cache.jl")
include("core/build_operations.jl")
include("core/build_simulations.jl")

#FeedForward Model Files
include("simulation_models/feedforward_models.jl")

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
include("routines/make_initial_conditions.jl")
include("routines/get_results.jl")
include("routines/solve_routines.jl")
include("routines/write_model.jl")

#Utils
include("utils/optimization_debugging.jl")
include("utils/printing.jl")
include("utils/plot_results.jl")
include("utils/plot_recipes.jl")
include("utils/aggregation.jl")

#Initialization

function __init__()
   Requires.@require Weave = "44d3d7a6-8a23-5bf8-98c5-b353f8df5ec9" include("utils/make_report.jl")
end


end
