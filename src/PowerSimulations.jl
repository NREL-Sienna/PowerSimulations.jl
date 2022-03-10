isdefined(Base, :__precompile__) && __precompile__()
module PowerSimulations

#################################################################################
# Exports

# Base Models
export Simulation
export DecisionModel
export EmulationModel
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
export NonSpinningReserve
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

######## Renewable Formulations ########
export BookKeeping
export BatteryAncillaryServices
export EnergyTarget

######## Thermal Formulations ########
export ThermalStandardUnitCommitment
export ThermalBasicUnitCommitment
export ThermalBasicCompactUnitCommitment
export ThermalBasicDispatch
export ThermalStandardDispatch
export ThermalDispatchNoMin
export ThermalMultiStartUnitCommitment
export ThermalCompactUnitCommitment
export ThermalCompactDispatch

###### Regulation Device Formulation #######
export DeviceLimitedRegulation
export ReserveLimitedRegulation

######## Hybrid Formulations ########
export BasicHybridDispatch
export StandardHybridDispatch

# feedforward models
export UpperBoundFeedforward
export LowerBoundFeedforward
export SemiContinuousFeedforward
export EnergyLimitFeedforward
export FixValueFeedforward
export EnergyTargetFeedforward

# InitialConditions chrons
export InterProblemChronology
export IntraProblemChronology

# Initial Conditions Quantities
export DevicePower
export DeviceStatus
export InitialTimeDurationOn
export InitialTimeDurationOff
export InitialEnergyLevel

# operation_models
export GenericOpProblem
export UnitCommitmentProblem
export EconomicDispatchProblem
# export OptimalPowerFlow

# Functions
export build!
## Op Model Exports
export get_initial_conditions
export serialize_problem
export serialize_results
export serialize_optimization_model
## Decision Model Export
export solve!
## Emulation Model Exports
export run!
## Sim Model Exports
export execute!
export get_simulation_model
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
export set_network_model!
export get_network_formulation
## Results interfaces
export SimulationResultsExport
export ProblemResultsExport
export export_results
export export_realized_results
export export_optimizer_stats
export get_variable_values
export get_dual_values
export get_parameter_values
export get_aux_variable_values
export get_expression_values
export get_timestamps
export get_model_name
export get_decision_problem_results
export get_emulation_problem_results
export get_system
export get_system!
export set_system!
export list_variable_keys
export list_dual_keys
export list_parameter_keys
export list_aux_variable_keys
export list_expression_keys
export list_variable_names
export list_dual_names
export list_parameter_names
export list_aux_variable_names
export list_expression_names
export list_decision_problems
export list_supported_formats
export load_results!
export read_variable
export read_dual
export read_parameter
export read_aux_variable
export read_expression
export read_variables
export read_duals
export read_parameters
export read_aux_variables
export read_expressions
export read_realized_variable
export read_realized_dual
export read_realized_parameter
export read_realized_aux_variable
export read_realized_expression
export read_realized_variables
export read_realized_duals
export read_realized_parameters
export read_realized_aux_variables
export read_realized_expressions
export get_realized_timestamps
export get_problem_base_power
export get_objective_value
export read_optimizer_stats

## Utils Exports
export get_all_constraint_index
export get_all_variable_index
export get_constraint_index
export get_variable_index
export list_recorder_events
export show_recorder_events
export list_simulation_events
export show_simulation_events
export export_realized_results

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
export FlowActivePowerFromToVariable
export FlowActivePowerToFromVariable
export FlowReactivePowerFromToVariable
export FlowReactivePowerToFromVariable
export PowerAboveMinimumVariable

# Auxiliary variables
export TimeDurationOn
export TimeDurationOff
export PowerOutput
export EnergyOutput

# Constraints
export AbsoluteValueConstraint
export ActiveConstraint
export ActivePowerVariableLimitsConstraint
export ActivePowerVariableTimeSeriesLimitsConstraint
export ActiveRangeConstraint
export ActiveRangeICConstraint
export AreaDispatchBalanceConstraint
export AreaParticipationAssignmentConstraint
export BalanceAuxConstraint
export CommitmentConstraint
export CopperPlateBalanceConstraint
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
export FeedforwardSemiContinousConstraint
export FeedforwardUpperBoundConstraint
export FeedforwardLowerBoundConstraint
export FeedforwardIntegralLimitConstraint
export FlowActivePowerConstraint
export FlowActivePowerFromToConstraint
export FlowActivePowerToFromConstraint
export FlowLimitConstraint
export FlowLimitFromToConstraint
export FlowLimitToFromConstraint
export FlowRateConstraint
export FlowRateConstraintFromTo
export FlowRateConstraintToFrom
export FlowReactivePowerConstraint
export FlowReactivePowerFromToConstraint
export FlowReactivePowerToFromConstraint
export FrequencyResponseConstraint
export HVDCPowerBalance
export HVDCTotalPowerDeliveredVariable
export InflowRangeConstraint
export InputActivePowerVariableLimitsConstraint
export InputPowerRangeConstraint
export MustRunConstraint
export NetworkFlowConstraint
export NodalBalanceActiveConstraint
export NodalBalanceReactiveConstraint
export OutputActivePowerVariableLimitsConstraint
export PieceWiseLinearCostConstraint
export PowerOutputRangeConstraint
export ParticipationAssignmentConstraint
export RampConstraint
export RampLimitConstraint
export RangeLimitConstraint
export RateLimitConstraint
export RateLimitConstraintFromTo
export RateLimitConstraintToFrom
export ReactivePowerVariableLimitsConstraint
export ReactiveRangeConstraint
export RegulationLimitsConstraint
export RequirementConstraint
export ReserveEnergyConstraint
export ReservePowerConstraint
export SACEPIDAreaConstraint
export StartTypeConstraint
export StartupInitialConditionConstraint
export StartupTimeLimitTemperatureConstraint

# Parameters
# Time Series Parameters
export ActivePowerTimeSeriesParameter
export ReactivePowerTimeSeriesParameter
export RequirementTimeSeriesParameter
export EnergyTargetTimeSeriesParameter
export EnergyBudgetTimeSeriesParameter

# Feedforward Parameters
export OnStatusParameter
export UpperBoundValueParameter

# Expressions
export SystemBalanceExpressions
export RangeConstraintLBExpressions
export RangeConstraintUBExpressions
export CostExpressions
export ActivePowerBalance
export ReactivePowerBalance
export EmergencyUp
export EmergencyDown
export RawACE
export ProductionCostExpression
export ActivePowerRangeExpressionLB
export ComponentActivePowerRangeExpressionLB
export ReserveRangeExpressionLB
export ActivePowerRangeExpressionUB
export ReserveRangeExpressionUB
export ComponentActivePowerRangeExpressionUB
export ComponentReserveUpBalanceExpression
export ComponentReserveDownBalanceExpression

#################################################################################
# Imports
import DataStructures: OrderedDict, Deque, SortedDict
import Logging
import Serialization
# Modeling Imports
import JuMP
# so that users do not need to import JuMP to use a solver with PowerModels
import JuMP: optimizer_with_attributes
import JuMP.Containers: DenseAxisArray, SparseAxisArray
export optimizer_with_attributes
import MathOptInterface
import ParameterJuMP
import LinearAlgebra
import JSON3
import PowerSystems
import InfrastructureSystems
import InfrastructureSystems: @assert_op, list_recorder_events, get_name
export get_name
export get_model_base_power
export get_optimizer_stats
export get_timestamps
export get_resolution
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

function progress_meter_enabled()
    return isa(stderr, Base.TTY) &&
           (get(ENV, "CI", nothing) != "true") &&
           (get(ENV, "RUNNING_PSI_TESTS", nothing) != "true")
end

using DocStringExtensions

@template DEFAULT = """
                    $(TYPEDSIGNATURES)
                    $(DOCSTRING)
                    $(METHODLIST)
                    """
# Includes

include("core/definitions.jl")

# Core components
include("core/formulations.jl")
include("core/abstract_simulation_store.jl")
include("core/operation_model_abstract_types.jl")
include("core/optimization_container_types.jl")
include("core/abstract_feedforward.jl")
include("core/optimization_container_keys.jl")
include("core/network_model.jl")
include("core/parameters.jl")
include("core/service_model.jl")
include("core/device_model.jl")
include("core/variables.jl")
include("core/auxiliary_variables.jl")
include("core/constraints.jl")
include("core/expressions.jl")
include("core/initial_conditions.jl")
include("core/settings.jl")
include("core/cache_utils.jl")
include("core/optimizer_stats.jl")
include("core/dataset.jl")
include("core/dataset_container.jl")

include("core/optimization_container.jl")
include("core/store_common.jl")

# Order Required
include("initial_conditions/initial_condition_chronologies.jl")

include("operation/problem_template.jl")
include("operation/operation_model_interface.jl")
include("operation/model_store_params.jl")
include("operation/abstract_model_store.jl")
include("operation/decision_model_store.jl")
include("operation/emulation_model_store.jl")
include("operation/initial_conditions_update_in_memory_store.jl")
include("operation/model_internal.jl")
include("operation/decision_model.jl")
include("operation/emulation_model.jl")
include("operation/problem_results_export.jl")
include("operation/problem_results.jl")
include("operation/operation_model_serialization.jl")
include("operation/time_series_interface.jl")
include("operation/optimization_debugging.jl")
include("operation/model_numerical_analysis_utils.jl")

include("initial_conditions/add_initial_condition.jl")
include("initial_conditions/update_initial_conditions.jl")
include("initial_conditions/calculate_initial_condition.jl")

include("parameters/add_parameters.jl")
include("parameters/update_parameters.jl")

include("feedforward/feedforwards.jl")
include("feedforward/feedforward_arguments.jl")
include("feedforward/feedforward_constraints.jl")

include("simulation/model_output_cache.jl")
include("simulation/optimization_output_cache.jl")
include("simulation/simulation_models.jl")
include("simulation/simulation_state.jl")
include("simulation/initial_condition_update_simulation.jl")
include("simulation/simulation_store_params.jl")
include("simulation/hdf_simulation_store.jl")
include("simulation/in_memory_simulation_store.jl")
include("simulation/simulation_problem_results.jl")
include("simulation/realized_meta.jl")
include("simulation/decision_model_simulation_results.jl")
include("simulation/emulation_model_simulation_results.jl")
include("simulation/simulation_sequence.jl")
include("simulation/simulation_internal.jl")
include("simulation/simulation.jl")
include("simulation/simulation_results_export.jl")
include("simulation/simulation_results.jl")

include("devices_models/devices/common/objective_functions.jl")
include("devices_models/devices/common/range_constraint.jl")
include("devices_models/devices/common/add_variable.jl")
include("devices_models/devices/common/add_auxiliary_variable.jl")
include("devices_models/devices/common/add_constraint_dual.jl")
include("devices_models/devices/common/rateofchange_constraints.jl")
include("devices_models/devices/common/duration_constraints.jl")
include("devices_models/devices/common/get_time_series.jl")

# Device Modeling components
include("devices_models/devices/interfaces.jl")
include("devices_models/devices/common/add_to_expression.jl")
include("devices_models/devices/common/set_expression.jl")
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
include("network_models/pm_translator.jl")
include("network_models/network_slack_variables.jl")
include("network_models/area_balance_model.jl")

include("initial_conditions/initialization.jl")

# Device constructors
include("devices_models/device_constructors/constructor_validations.jl")
include("devices_models/device_constructors/thermalgeneration_constructor.jl")
include("devices_models/device_constructors/hydrogeneration_constructor.jl")
include("devices_models/device_constructors/branch_constructor.jl")
include("devices_models/device_constructors/renewablegeneration_constructor.jl")
include("devices_models/device_constructors/load_constructor.jl")
include("devices_models/device_constructors/storage_constructor.jl")
include("devices_models/device_constructors/regulationdevice_constructor.jl")
include("devices_models/device_constructors/hybridgeneration_constructor.jl")
# Network constructors
include("network_models/network_constructor.jl")

# Templates for Operation Problems
include("operation/operation_problem_templates.jl")

# Operations Decision Problems
include("operation/decision_problems.jl")

# Utils
include("utils/printing.jl")
include("utils/file_utils.jl")
include("utils/logging.jl")
include("utils/dataframes_utils.jl")
include("utils/jump_utils.jl")
include("utils/powersystems_utils.jl")
include("utils/recorder_events.jl")
include("utils/datetime_utils.jl")

end
