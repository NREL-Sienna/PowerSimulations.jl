isdefined(Base, :__precompile__) && __precompile__()
module PowerSimulations

#################################################################################
# Exports

# Base Models
export Stage
export Simulation
export OperationsProblem
export OperationsProblemTemplate
export InitialCondition

#Network Relevant Exports
export StandardPTDFModel
export CopperPlatePowerModel

######## Device Models ########
export DeviceModel
######## Service Models ########
export ServiceModel
export RangeReserve
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
export HydroDispatchRunOfRiver
export HydroDispatchSeasonalFlow
export HydroCommitmentRunOfRiver
export HydroCommitmentSeasonalFlow
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
export GenericOpProblem
#export UnitCommitment
#export EconomicDispatch
#export OptimalPowerFlow

# Functions
## Construction Exports
export construct_device!
export construct_network!
## Op Model Exports
export solve_op_problem!
export get_initial_conditions
export set_transmission_model!
export set_devices_template!
export set_branches_template!
export set_services_template!
export set_device_model!
export set_branch_model!
export set_device_model!
## Sim Model Exports
export make_references
export execute!
## Utils Exports
export SimulationResultsReference
export get_sim_resolution
export write_op_problem
export write_results
export check_file_integrity
export load_operation_results
export load_simulation_results
export write_to_CSV
export get_all_constraint_index
export get_all_var_index
export get_con_index
export get_var_index

# Plotting Utils
export sort_data
export get_stacked_plot_data
export get_bar_plot_data
export get_stacked_generation_data
export get_stacked_aggregation_data
export bar_plot
export stack_plot
export report
export make_fuel_dictionary
export fuel_plot

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
import Colors
import JSON
import CSV
import SHA

include("core/definitions.jl")

#################################################################################
##### JuMP methods overloading
JuMP.Model(optimizer::Nothing; kwargs...) = JuMP.Model(kwargs...)

################################################################################
# Includes

include("utils/utils.jl")

#Models and constructors
include("core/core_structs/aux_structs.jl")
include("core/core_structs/cache.jl")
include("core/core_structs/feedforward.jl")
include("services_models/services_model.jl")
include("devices_models/device_model.jl")
include("network_models/networks.jl")
include("core/core_structs/initial_conditions.jl")
include("core/core_structs/psi_container.jl")
include("core/core_structs/operations_problem.jl")
include("core/core_structs/chronology.jl")
include("core/core_structs/simulations_stages.jl")
include("core/core_structs/simulation.jl")
include("core/core_structs/operations_problem_results.jl")
include("core/build_cache.jl")
include("core/build_operations.jl")
include("core/build_simulations.jl")

#FeedForward Model Files
include("simulation/feedforward_affects.jl")

#Device Modeling components
include("devices_models/devices/common.jl")
include("devices_models/devices/renewable_generation.jl")
include("devices_models/devices/thermal_generation.jl")
include("devices_models/devices/electric_loads.jl")
include("devices_models/devices/AC_branches.jl")
include("devices_models/devices/DC_branches.jl")
include("devices_models/devices/storage.jl")
include("devices_models/devices/hydro_generation.jl")

#Network models
include("network_models/copperplate_model.jl")
include("network_models/powermodels_interface.jl")
include("network_models/ptdf_model.jl")

#Device constructors
include("devices_models/device_constructors/common/constructor_validations.jl")
include("devices_models/device_constructors/common/device_constructor_utils.jl")
include("devices_models/device_constructors/thermalgeneration_constructor.jl")
include("devices_models/device_constructors/hydrogeneration_constructor.jl")
include("devices_models/device_constructors/branch_constructor.jl")
include("devices_models/device_constructors/renewablegeneration_constructor.jl")
include("devices_models/device_constructors/load_constructor.jl")
include("devices_models/device_constructors/storage_constructor.jl")

#Network constructors
include("network_models/network_constructor.jl")

#Services Models
include("services_models/reserves.jl")
include("services_models/services_constructor.jl")

# Commented out until properly implemented
#Operational Model Constructors
#include("operation_templates/economic_dispatch.jl")
#include("operation_templates/unit_commitment.jl")
#include("operation_templates/opf.jl")

#Simulations Model Files
include("simulation/stage_update.jl")

#Routines
include("routines/make_initial_conditions.jl")
include("routines/get_results.jl")
include("routines/solve_routines.jl")

#Utils
include("utils/optimization_debugging.jl")
include("utils/dual_results.jl")
include("utils/simulation_results_reference.jl")
include("utils/simulation_results.jl")
include("utils/printing.jl")
#Routines
include("routines/write_results.jl")

#Initialization
function __init__()
   Requires.@require Weave = "44d3d7a6-8a23-5bf8-98c5-b353f8df5ec9" include("utils/make_report.jl")
end


end
