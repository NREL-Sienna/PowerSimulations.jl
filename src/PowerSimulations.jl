isdefined(Base, :__precompile__) && __precompile__()
module PowerSimulations

#################################################################################
# Exports

# Base Models
export Simulation
export OperationsProblem
export ProblemResults
export OperationsProblemTemplate
export InitialCondition
export SimulationProblems
export SimulationSequence
export SimulationResults

# Network Relevant Exports
export StandardPTDFModel
export PTDFPowerModel
export CopperPlatePowerModel
export AreaBalancePowerModel

######## Device Models ########
export DeviceModel
export FixedOutput
######## Service Models ########
export ServiceModel
export RangeReserve
export RampReserve
export StepwiseCostReserve
export PIDSmoothACE
export GroupReserve
######## Branch Models ########
export StaticBranch
export StaticBranchBounds
export StaticBranchUnbounded
export HVDCLossless
export HVDCDispatch
export HVDCUnbounded
# export VoltageSourceDC
######## Load Models ########
export StaticPowerLoad
export InterruptiblePowerLoad
export DispatchablePowerLoad
######## Renewable Formulations ########
export RenewableFullDispatch
export RenewableConstantPowerFactor
######## Hydro Formulations ########
export HydroDispatchRunOfRiver
export HydroDispatchReservoirBudget
export HydroDispatchReservoirStorage
export HydroCommitmentRunOfRiver
export HydroCommitmentReservoirBudget
export HydroCommitmentReservoirStorage
export HydroDispatchPumpedStorage
export HydroDispatchPumpedStoragewReservation
######## Renewable Formulations ########
export BookKeeping
export BookKeepingwReservation
export BatteryAncialliryServices
export EnergyTarget

######## Thermal Formulations ########
export ThermalStandardUnitCommitment
export ThermalBasicUnitCommitment
export ThermalDispatch
export ThermalRampLimited
export ThermalDispatchNoMin
export ThermalMultiStartUnitCommitment
export ThermalCompactUnitCommitment

######## HybridSystem Formulations ########
export PhysicalCoupling
export FinancialCoupling
export StandardHybridFormulation

export FinancialCouplingDisaptch
export StandardHybridFormulationDisaptch

###### Regulation Device Formulation #######
export DeviceLimitedRegulation
export ReserveLimitedRegulation

# feedforward chrons
export RecedingHorizon
export Synchronize
export Consecutive
export FullHorizon
export Range

# feedforward models
export UpperBoundFF
export SemiContinuousFF
export RangeFF
export IntegralLimitFF
export ParameterFF
export PowerCommitmentFF

# InitialConditions chrons
export InterProblemChronology
export IntraProblemChronology

# Initial Conditions Quantities
export DevicePower
export DeviceStatus
export InitialTimeDurationOn
export InitialTimeDurationOff
export InitialEnergyLevel

# cache_models
export TimeStatusChange
export StoredEnergy

# operation_models
export GenericOpProblem
export UnitCommitmentProblem
export EconomicDispatchProblem
# export OptimalPowerFlow

# Functions
## Op Model Exports
export solve!
export get_initial_conditions
export serialize_problem
export serialize_optimization_model
## Sim Model Exports
export build!
export execute!
## Template Exports
export template_economic_dispatch
export template_unit_commitment
export template_agc_reserve_deployment
export EconomicDispatchProblem
export UnitCommitmentProblem
export AGCReserveDeployment
export run_economic_dispatch
export run_unit_commitment
export set_device_model!
export set_service_model!
export set_transmission_model!
export get_transmission_model
## Results interfaces
export SimulationResultsExport
export ProblemResultsExport
export export_results
export get_existing_duals
export get_existing_parameters
export get_existing_timestamps
export get_existing_variables
export get_problem_name
export get_problem_results
export get_system
export get_system!
export set_system!
export list_problems
export list_supported_formats
export load_results!
export read_dual
export read_duals
export read_realized_duals
export read_realized_variables
export read_realized_parameters
export get_realized_timestamps
export read_variable
export read_variables
export read_parameter
export read_parameters
export get_problem_base_power
export get_objective_value
export read_optimizer_stats

## Utils Exports
export get_all_constraint_index
export get_all_var_index
export get_con_index
export get_var_index
export show_recorder_events
export list_simulation_events
export show_simulation_events
export write_results
export write_to_CSV

## Enums
export BuildStatus
export RunStatus

# Variables / Parameters
export ACTIVE_POWER
export ENERGY
export ENERGY_BUDGET
export FLOW_ACTIVE_POWER
export ON
export REACTIVE_POWER
export ACTIVE_POWER_IN
export ACTIVE_POWER_OUT
export RESERVE
export SERVICE_REQUIREMENT
export START
export STOP
export THETA
export VM
export INFLOW
export SPILLAGE
export SLACK_UP
export SLACK_DN

# Constraints
export ACTIVE
export ACTIVE_RANGE
export ACTIVE_RANGE_LB
export ACTIVE_RANGE_UB
export COMMITMENT
export DURATION
export DURATION_DOWN
export DURATION_UP
export ENERGY_CAPACITY
export ENERGY_LIMIT
export FEEDFORWARD
export FEEDFORWARD_UB
export FEEDFORWARD_BIN
export FEEDFORWARD_INTEGRAL_LIMIT
export FLOW_LIMIT
export FLOW_LIMIT_FROM_TO
export FLOW_LIMIT_TO_FROM
export FLOW_REACTIVE_POWER_FROM_TO
export FLOW_REACTIVE_POWER_TO_FROM
export FLOW_ACTIVE_POWER_FROM_TO
export FLOW_ACTIVE_POWER_TO_FROM
export FLOW_ACTIVE_POWER
export FLOW_REACTIVE_POWER
export INPUT_POWER_RANGE
export OUTPUT_POWER_RANGE
export RAMP
export RAMP_DOWN
export RAMP_UP
export RATE_LIMIT
export RATE_LIMIT_FT
export RATE_LIMIT_TF
export REACTIVE
export REACTIVE_RANGE
export REQUIREMENT
export INFLOW_RANGE

#################################################################################
# Imports
import DataStructures: OrderedDict, Deque, SortedDict
import Logging
import Serialization
# Modeling Imports
import JuMP
# so that users do not need to import JuMP to use a solver with PowerModels
import JuMP: optimizer_with_attributes
export optimizer_with_attributes
import MathOptInterface
import ParameterJuMP
import LinearAlgebra
import JSON3
import PowerSystems
import InfrastructureSystems
# so that users have access to IS.Results interfaces
import InfrastructureSystems:
    get_variables,
    get_parameters,
    get_total_cost,
    get_optimizer_stats,
    write_results,
    get_timestamp,
    get_resolution,
    get_name,
    @assert_op
export get_name
export get_model_base_power
export get_variables
export get_duals
export get_parameters
export get_total_cost
export get_optimizer_stats
export get_timestamp
export get_timestamps
export get_resolution
export write_results
import PowerModels
import TimerOutputs
import ProgressMeter

# Base Imports
import Base.getindex
import Base.length
import Base.first

# TimeStamp Management Imports
import Dates
import TimeSeries

# I/O Imports
import DataFrames
import JSON
import CSV
import SHA
import HDF5

# PowerModels exports
export ACPPowerModel
export ACRPowerModel
export ACTPowerModel
export DCPPowerModel
export NFAPowerModel
export DCPLLPowerModel
export LPACCPowerModel
export SOCWRPowerModel
export SOCWRConicPowerModel
export QCRMPowerModel
export QCLSPowerModel

################################################################################

# Type Alias From other Packages
const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const IS = InfrastructureSystems
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities
const PJ = ParameterJuMP
const MOPFM = MOI.FileFormats.Model
const TS = TimeSeries

################################################################################
# Includes

include("utils.jl")

include("core/definitions.jl")

# Models and constructors
include("core/results.jl")
include("core/abstract_types.jl")
include("core/aux_structs.jl")

include("core/powermodels_formulations.jl")
include("core/service_models.jl")
include("core/device_models.jl")

include("core/parameters.jl")
include("core/variables.jl")
include("core/auxiliary_variables.jl")
include("core/constraints.jl")
include("core/cache.jl")
include("core/feedforward_chronologies.jl")
include("core/optimizer_stats.jl")
include("core/initial_condition_types.jl")
include("core/initial_condition.jl")
include("core/initial_conditions.jl")
include("core/operations_problem_template.jl")
include("core/settings.jl")
include("core/cache_utils.jl")
include("core/param_result_cache.jl")
include("core/result_cache.jl")
include("core/simulation_store.jl")
include("core/hdf_simulation_store.jl")
include("core/in_memory_simulation_store.jl")
include("core/problem_results_export.jl")
include("core/simulation_results_export.jl")
include("core/optimization_container.jl")
include("core/update_initial_conditions.jl")
include("core/operations_problem.jl")
include("core/operations_problem_results.jl")
include("core/simulation_problems.jl")
include("core/simulation_sequence.jl")
include("core/simulation.jl")

include("devices_models/devices/common/constraints_structs.jl")
include("devices_models/devices/common/cost_functions.jl")
include("devices_models/devices/common/range_constraint.jl")
include("devices_models/devices/common/add_variable.jl")
include("devices_models/devices/common/add_auxiliary_variable.jl")
include("devices_models/devices/common/add_parameters.jl")
include("devices_models/devices/common/rating_constraints.jl")
include("devices_models/devices/common/rateofchange_constraints.jl")
include("devices_models/devices/common/duration_constraints.jl")
include("devices_models/devices/common/commitment_constraint.jl")
include("devices_models/devices/common/timeseries_constraint.jl")
include("devices_models/devices/common/expressionarray_algebra.jl")
include("devices_models/devices/common/energy_balance_constraint.jl")
include("devices_models/devices/common/energy_management_constraints.jl")
include("devices_models/devices/common/get_time_series.jl")
include("devices_models/devices/common/hybrid_constraints.jl")

include("core/feedforward.jl")
include("core/problem_results.jl")
include("core/simulation_results.jl")
include("core/recorder_events.jl")

# Device Modeling components
include("devices_models/devices/interfaces.jl")
include("devices_models/devices/common/device_range_constraints.jl")
include("devices_models/devices/common/nodal_expression.jl")
include("devices_models/devices/renewable_generation.jl")
include("devices_models/devices/thermal_generation.jl")
include("devices_models/devices/electric_loads.jl")
include("devices_models/devices/AC_branches.jl")
include("devices_models/devices/DC_branches.jl")
include("devices_models/devices/storage.jl")
include("devices_models/devices/hydro_generation.jl")
include("devices_models/devices/regulation_device.jl")
include("devices_models/devices/hybrid_generation.jl")

# Services Models
include("services_models/agc.jl")
include("services_models/reserves.jl")
include("services_models/group_reserve.jl")
include("services_models/service_slacks.jl")
include("services_models/services_constructor.jl")

# Network models
include("network_models/copperplate_model.jl")
include("network_models/powermodels_interface.jl")
include("devices_models/devices/common/pm_translator.jl")
include("network_models/network_slack_variables.jl")
include("network_models/area_balance_model.jl")

# Device constructors
include("devices_models/device_constructors/common/constructor_validations.jl")
include("devices_models/device_constructors/thermalgeneration_constructor.jl")
include("devices_models/device_constructors/hydrogeneration_constructor.jl")
include("devices_models/device_constructors/branch_constructor.jl")
include("devices_models/device_constructors/renewablegeneration_constructor.jl")
include("devices_models/device_constructors/load_constructor.jl")
include("devices_models/device_constructors/storage_constructor.jl")
include("devices_models/device_constructors/regulationdevice_constructor.jl")
include("devices_models/device_constructors/hybrid_constructor.jl")

# Network constructors
include("network_models/network_constructor.jl")

# Templates
include("operations_problem_templates.jl")

# Operations Problems
include("operations_problems.jl")

# Printing
include("printing.jl")

end
