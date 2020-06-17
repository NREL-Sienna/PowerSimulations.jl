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
export SimulationSequence

#Network Relevant Exports
export StandardPTDFModel
export CopperPlatePowerModel
export AreaBalancePowerModel

######## Device Models ########
export DeviceModel
export FixedOutput
######## Service Models ########
export ServiceModel
export RangeReserve
export StepwiseCostReserve
export PIDSmoothACE
######## Branch Models ########
export StaticLine
export StaticLineBounds
export StaticLineUnbounded
export StaticTransformer
export StaticTransformerBounds
export StaticTransformerUnbounded
export FlowMonitoredLine
export HVDCLossless
export HVDCDispatch
export HVDCUnbounded
#export VoltageSourceDC
######## Load Models ########
export StaticPowerLoad
export InterruptiblePowerLoad
export DispatchablePowerLoad
######## Renewable Formulations ########
export RenewableFullDispatch
export RenewableConstantPowerFactor
######## Hydro Formulations ########
export HydroDispatchRunOfRiver
export HydroDispatchReservoirFlow
export HydroDispatchReservoirStorage
# export HydroCommitmentRunOfRiver
# export HydroCommitmentReservoirFlow
# export HydroCommitmentReservoirStorage
######## Renewable Formulations ########
export BookKeeping
export BookKeepingwReservation
######## Thermal Formulations ########
export ThermalStandardUnitCommitment
export ThermalBasicUnitCommitment
export ThermalDispatch
export ThermalRampLimited
export ThermalDispatchNoMin

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

# InitialConditions chrons
export InterStageChronology
export IntraStageChronology

# Initial Conditions Quantities
export DevicePower
export DeviceStatus
export TimeDurationON
export TimeDurationOFF
export EnergyLevel

# cache_models
export TimeStatusChange
export StoredEnergy

#operation_models
export GenericOpProblem
export UnitCommitmentProblem
export EconomicDispatchProblem
#export OptimalPowerFlow

# Functions
## Construction Exports
export construct_device!
export construct_network!
## Op Model Exports
export solve!
export get_initial_conditions
export set_transmission_model!
export set_devices_template!
export set_branches_template!
export set_services_template!
export set_device_model!
export set_branch_model!
export set_device_model!
## Sim Model Exports
export build!
export execute!
export make_references
## Template Exports
export template_economic_dispatch
export template_unit_commitment
export template_agc_reserve_deployment
export EconomicDispatchProblem
export UnitCommitmentProblem
export AGCReserveDeployment
export run_economic_dispatch
export run_unit_commitment
## Results interfaces
export get_duals

## Utils Exports
export SimulationResultsReference
export write_results
export check_file_integrity
export load_operation_results
export load_simulation_results
export write_to_CSV
export get_all_constraint_index
export get_all_var_index
export get_con_index
export get_var_index
export get_result_variable
export get_variable_names
export configure_logging
export show_recorder_events
export list_simulation_events
export show_simulation_events

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
import Logging
import Serialization
#Modeling Imports
import JuMP
# so that users do not need to import JuMP to use a solver with PowerModels
import JuMP: optimizer_with_attributes
export optimizer_with_attributes
import MathOptInterface
import ParameterJuMP
import LinearAlgebra
import PowerSystems
import InfrastructureSystems
# so that users have access to IS.Results interfaces
import InfrastructureSystems:
    get_base_power,
    get_variables,
    get_total_cost,
    get_optimizer_log,
    get_time_stamp,
    write_results
export get_base_power
export get_variables
export get_dual_values
export get_total_cost
export get_optimizer_log
export get_time_stamp
export write_results
import PowerModels
import TimerOutputs

#TimeStamp Management Imports
import Dates
import TimeSeries

#I/O Imports
import DataFrames
import Feather
import JSON
import CSV
import SHA

include("core/definitions.jl")

################################################################################
# Includes

include("logging.jl")
include("utils.jl")

#Models and constructors
include("core/abstract_types.jl")
include("core/aux_structs.jl")

include("services_models/services_model.jl")
include("devices_models/device_model.jl")
include("network_models/networks.jl")

include("core/parameters.jl")
include("core/cache.jl")
include("core/initial_condition_types.jl")
include("core/initial_condition.jl")
include("core/initial_conditions.jl")
include("core/operations_problem_template.jl")
include("core/psi_settings.jl")
include("core/psi_container.jl")
include("core/update_initial_conditions.jl")
include("core/operations_problem_results.jl")
include("core/operations_problem.jl")
include("core/simulation_stages.jl")
include("core/simulation_sequence.jl")
include("core/simulation.jl")
include("devices_models/devices/common.jl")
include("core/feedforward.jl")
include("core/simulation_results.jl")
include("core/recorder_events.jl")

#Device Modeling components
include("devices_models/devices/common/device_range_constraints.jl")
include("devices_models/devices/common/activepower_constraints.jl")
include("devices_models/devices/common/reactivepower_constraints.jl")
include("devices_models/devices/common/nodal_expression.jl")
include("devices_models/devices/renewable_generation.jl")
include("devices_models/devices/thermal_generation.jl")
include("devices_models/devices/electric_loads.jl")
include("devices_models/devices/AC_branches.jl")
include("devices_models/devices/DC_branches.jl")
include("devices_models/devices/storage.jl")
include("devices_models/devices/hydro_generation.jl")
include("devices_models/devices/regulation_device.jl")

#Services Models
include("services_models/agc.jl")
include("services_models/reserves.jl")
include("services_models/service_slacks.jl")
include("services_models/services_constructor.jl")

#Network models
include("network_models/copperplate_model.jl")
include("network_models/powermodels_interface.jl")
include("network_models/ptdf_model.jl")
include("network_models/network_slack_variables.jl")
include("network_models/area_balance_model.jl")

#Device constructors
include("devices_models/device_constructors/common/constructor_validations.jl")
include("devices_models/device_constructors/thermalgeneration_constructor.jl")
include("devices_models/device_constructors/hydrogeneration_constructor.jl")
include("devices_models/device_constructors/branch_constructor.jl")
include("devices_models/device_constructors/renewablegeneration_constructor.jl")
include("devices_models/device_constructors/load_constructor.jl")
include("devices_models/device_constructors/storage_constructor.jl")
include("devices_models/device_constructors/regulationdevice_constructor.jl")

#Network constructors
include("network_models/network_constructor.jl")

#Templates
include("operations_problems_templates.jl")
# Printing
include("printing.jl")

end
