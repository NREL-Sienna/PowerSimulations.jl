isdefined(Base, :__precompile__) && __precompile__()
module PowerSimulations

#################################################################################
# Exports

# Base Models
export Simulation
export DecisionModel
export ProblemResults
export ProblemTemplate
export InitialCondition
export SimulationModels
export SimulationSequence
export SimulationResults

# Network Relevant Exports
export NetworkModel
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
export BatteryAncillaryServices
export EnergyTarget

######## Thermal Formulations ########
export ThermalStandardUnitCommitment
export ThermalBasicUnitCommitment
export ThermalDispatch
export ThermalRampLimited
export ThermalDispatchNoMin
export ThermalMultiStartUnitCommitment
export ThermalCompactUnitCommitment

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
export IntegralLimitFF
export ParameterFF

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
export get_network_formulation
## Results interfaces
export SimulationResultsExport
export ProblemResultsExport
export export_results
export get_dual_values
export get_parameter_values
export get_variable_values
export get_timestamps
export get_problem_name
export get_problem_results
export get_system
export get_system!
export set_system!
export list_dual_names
export list_parameter_names
export list_variable_names
export list_problems
export list_supported_formats
export load_results!
export read_dual
#export read_realized_duals
#export read_realized_variables
#export read_realized_parameters
#export get_realized_timestamps
export read_variable
export read_parameter
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

# Variables
export ActivePowerVariable
export ActivePowerInVariable
export ActivePowerOutVariable
export HotStartVariable
export WarmStartVariable
export ColdStartVariable
export EnergyVariable
export EnergyVariableUp
export EnergyVariableDown
export EnergyShortageVariable
export EnergySurplusVariable
export LiftVariable
export OnVariable
export ReactivePowerVariable
export ReservationVariable
export ActivePowerReserveVariable
export ServiceRequirementVariable
export WaterSpillageVariable
export StartVariable
export StopVariable
export SteadyStateFrequencyDeviation
export AreaMismatchVariable
export DeltaActivePowerUpVariable
export DeltaActivePowerDownVariable
export AdditionalDeltaActivePowerUpVariable
export AdditionalDeltaActivePowerDownVariable
export SmoothACE
export SystemBalanceSlackUp
export SystemBalanceSlackDown
export ReserveRequirementSlack
export VoltageMagnitude
export VoltageAngle
export FlowActivePowerVariable
export FlowReactivePowerVariable
export FlowActivePowerFromToVariable
export FlowActivePowerToFromVariable
export FlowReactivePowerFromToVariable
export FlowReactivePowerToFromVariable

# Auxiliary variables
export TimeDurationOn
export TimeDurationOff
export PowerOutput

# Constraints
export AbsoluteValueConstraint
export ActiveConstraint
export ActivePowerVariableLimitsConstraint
export ActiveRangeConstraint
export ActiveRangeICConstraint
export AreaDispatchBalanceConstraint
export AreaParticipationAssignmentConstraint
export BalanceAuxConstraint
export CommitmentConstraint
export CopperPlateBalanceConstraint
export DeltaActivePowerDownVariableLimitsConstraint
export DeltaActivePowerUpVariableLimitsConstraint
export DurationConstraint
export EnergyBalanceConstraint
export EnergyBudgetConstraint
export EnergyCapacityConstraint
export EnergyCapacityDownConstraint
export EnergyCapacityUpConstraint
export EnergyLimitConstraint
export EnergyShortageVariableLimitsConstraint
export EnergyTargetConstraint
export EqualityConstraint
export FeedforwardBinConstraint
export FeedforwardConstraint
export FeedforwardIntegralLimitConstraint
export FeedforwardUBConstraint
export FlowActivePowerConstraint
export FlowActivePowerFromToConstraint
export FlowActivePowerToFromConstraint
export FlowLimitConstraint
export FlowLimitFromToConstraint
export FlowLimitToFromConstraint
export FlowRateConstraint
export FlowRateConstraintFT
export FlowRateConstraintTF
export FlowReactivePowerConstraint
export FlowReactivePowerFromToConstraint
export FlowReactivePowerToFromConstraint
export FrequencyResponseConstraint
export InflowRangeConstraint
export InputActivePowerVariableLimitsConstraint
export InputPowerRangeConstraint
export MustRunConstraint
export NetworkFlowConstraint
export NodalBalanceActiveConstraint
export NodalBalanceReactiveConstraint
export OutputActivePowerVariableLimitsConstraint
export OutputPowerRangeConstraint
export ParticipationAssignmentConstraint
export RampConstraint
export RampLimitConstraint
export RangeLimitConstraint
export RateLimitConstraint
export RateLimitFTConstraint
export RateLimitTFConstraint
export ReactiveConstraint
export ReactivePowerVariableLimitsConstraint
export ReactiveRangeConstraint
export RegulationLimitsDownConstraint
export RegulationLimitsUpConstraint
export RequirementConstraint
export ReserveEnergyConstraint
export ReservePowerConstraint
export SACEPidAreaConstraint
export StartTypeConstraint
export StartupInitialConditionConstraint
export StartupTimeLimitTemperatureConstraint

# Parameters
export ActivePowerTimeSeriesParameter
export ReactivePowerTimeSeriesParameter
export RequirementTimeSeriesParameter
export EnergyTargetTimeSeriesParameter
export EnergyBudgetTimeSeriesParameter
export BinaryValueParameter
export UpperBoundValueParameter

#export register_types!
#export empty_registrations!

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

include("core/definitions.jl")

# Core components
include("core/abstract_types.jl")
include("core/optimization_container_keys.jl")
include("core/aux_structs.jl")
include("network_models/powermodels_formulations.jl")
include("core/network_model.jl")
include("core/service_model.jl")
include("core/parameters.jl")
include("core/device_model.jl")
include("core/variables.jl")
include("core/auxiliary_variables.jl")
include("core/constraints.jl")
include("core/cache.jl")
include("core/settings.jl")
include("core/cache_utils.jl")
include("core/optimizer_stats.jl")

include("initial_conditions/initial_conditions.jl")
include("initial_conditions/initial_condition.jl")
include("initial_conditions/initial_condition_chronologies.jl")

# TODO: Clean the Initial Condition relationship with the Optimization Container
include("core/optimization_container.jl")
include("initial_conditions/update_initial_conditions.jl")

include("operation/problem_template.jl")
include("operation/operation_model_interface.jl")
include("operation/problem_internal.jl")
include("operation/decision_model.jl")
include("operation/problem_results_export.jl")
include("operation/problem_results.jl")

include("feedforward/feedforward_chronologies.jl")
include("feedforward/feedforward_structs.jl")

include("simulation/param_result_cache.jl")
include("simulation/result_cache.jl")
include("simulation/simulation_store.jl")
include("simulation/hdf_simulation_store.jl")
include("simulation/in_memory_simulation_store.jl")
include("simulation/simulation_problem_results.jl")
include("simulation/simulation_models.jl")
include("simulation/simulation_sequence.jl")
include("simulation/simulation.jl")
include("simulation/simulation_results_export.jl")
include("simulation/simulation_results.jl")

include("devices_models/devices/common/constraints_structs.jl")
include("devices_models/devices/common/cost_functions.jl")
include("devices_models/devices/common/range_constraint.jl")
include("devices_models/devices/common/add_variable.jl")
include("devices_models/devices/common/add_auxiliary_variable.jl")
include("devices_models/devices/common/add_dual_variable.jl")
include("devices_models/devices/common/add_parameters.jl")
include("devices_models/devices/common/rating_constraints.jl")
include("devices_models/devices/common/rateofchange_constraints.jl")
include("devices_models/devices/common/duration_constraints.jl")
include("devices_models/devices/common/commitment_constraint.jl")
include("devices_models/devices/common/timeseries_constraint.jl")
include("devices_models/devices/common/expressionarray_algebra.jl")
include("devices_models/devices/common/get_time_series.jl")

include("feedforward/feedforward_constraints.jl")

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

# Services Models
include("services_models/agc.jl")
include("services_models/reserves.jl")
include("services_models/group_reserve.jl")
include("services_models/service_slacks.jl")
include("services_models/services_constructor.jl")

# Network models
include("network_models/copperplate_model.jl")
include("network_models/powermodels_interface.jl")
include("network_models/pm_translator.jl")
include("network_models/network_slack_variables.jl")
include("network_models/area_balance_model.jl")

include("initial_conditions/initialization.jl")

# Device constructors
include("devices_models/device_constructors/common/constructor_validations.jl")
include("devices_models/device_constructors/thermalgeneration_constructor.jl")
include("devices_models/device_constructors/hydrogeneration_constructor.jl")
include("devices_models/device_constructors/branch_constructor.jl")
include("devices_models/device_constructors/renewablegeneration_constructor.jl")
include("devices_models/device_constructors/load_constructor.jl")
include("devices_models/device_constructors/storage_constructor.jl")
include("devices_models/device_constructors/regulationdevice_constructor.jl")

# Network constructors
include("network_models/network_constructor.jl")

# Templates for Operation Problems
include("operation/operation_problem_templates.jl")

# Operations Decision Problems
include("operation/decision_problems.jl")

# Utils
include("utils/jump_model_utils.jl")
include("utils/printing.jl")
include("utils/file_utils.jl")
include("utils/logging.jl")
include("utils/dataframes_utils.jl")
include("utils/jump_utils.jl")
include("utils/powersystems_utils.jl")
include("utils/recorder_events.jl")

end
