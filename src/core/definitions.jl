#################################################################################
#Type Alias for long type signatures
const MinMax = NamedTuple{(:min, :max), NTuple{2, Float64}}
const NamedMinMax = Tuple{String, MinMax}
const UpDown = NamedTuple{(:up, :down), NTuple{2, Float64}}
const InOut = NamedTuple{(:in, :out), NTuple{2, Float64}}
const StartUpStages = NamedTuple{(:hot, :warm, :cold), NTuple{3, Float64}}

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

const BUILD_SIMULATION_TIMER = TimerOutputs.TimerOutput()
const RUN_SIMULATION_TIMER = TimerOutputs.TimerOutput()

#Type Alias for JuMP and PJ containers
const JuMPExpressionMatrix = Matrix{<:JuMP.AbstractJuMPScalar}
const PGAE = PJ.ParametrizedGenericAffExpr{Float64, JuMP.VariableRef}
const GAE = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}
const JuMPAffineExpressionArray = Matrix{GAE}
const JuMPAffineExpressionVector = Vector{GAE}
const JuMPConstraintArray = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}
const JuMPVariableArray = JuMP.Containers.DenseAxisArray{JuMP.VariableRef}
const JuMPParamArray = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}
const DenseAxisArrayContainer = Dict{Symbol, JuMP.Containers.DenseAxisArray}

@enum BUILD_STATUS begin
    BUILT = 1
    IN_PROGRESS = -1
    EMPTY = 0
end

# Settings constants
const UNSET_HORIZON = 0
const UNSET_INI_TIME = Dates.DateTime(0)

# Tolerance of comparisons
# MIP gap tolerances in most solvers are set to 1e-4
const ABSOLUTE_TOLERANCE = 1.0e-3
const BALANCE_SLACK_COST = 1e6
const SERVICES_SLACK_COST = 1e5
const COST_EPSILON = 1e-3
const MISSING_INITIAL_CONDITIONS_TIME_COUNT = 999.0
const SECONDS_IN_MINUTE = 60.0
const MINUTES_IN_HOUR = 60.0
const SECONDS_IN_HOUR = 3600.0
const MAX_START_STAGES = 3

# Interface limitations
const OPERATIONS_ACCEPTED_KWARGS = [
    :horizon,
    :initial_time,
    :use_forecast_data,
    :PTDF,
    :use_parameters,
    :optimizer,
    :warm_start,
    :balance_slack_variables,
    :services_slack_variables,
    :system_to_file,
    :constraint_duals,
    :export_pwl_vars,
]

const OPERATIONS_SOLVE_KWARGS = [:optimizer, :save_path]

const STAGE_ACCEPTED_KWARGS = [
    :PTDF,
    :warm_start,
    :balance_slack_variables,
    :services_slack_variables,
    :constraint_duals,
    :system_to_file,
    :export_pwl_vars,
    :allow_fails,
]

const UNSUPPORTED_POWERMODELS =
    [PM.SOCBFPowerModel, PM.SOCBFConicPowerModel, PM.IVRPowerModel]

const PSI_NAME_DELIMITER = "__"

const M_VALUE = 1e6

# The constants below are strings instead of enums because there is a requirement that users
# should be able to define their own without changing PowerSimulations.

# Variables / Parameters
const ACTIVE_POWER = "P"
const ENERGY = "E"
const ENERGY_BUDGET = "energy_budget"
const FLOW_ACTIVE_POWER = "Fp"
const ON = "On"
const REACTIVE_POWER = "Q"
const ACTIVE_POWER_IN = "Pin"
const ACTIVE_POWER_OUT = "Pout"
const RESERVE = "R"
const SERVICE_REQUIREMENT = "service_requirement"
const START = "Start"
const STOP = "Stop"
const THETA = "theta"
const VM = "Vm"
const INFLOW = "In"
const SPILLAGE = "Sp"
const SLACK_UP = "γ⁺"
const SLACK_DN = "γ⁻"
const COLD_START = "start_cold"
const WARM_START = "start_warm"
const HOT_START = "start_hot"

# Constraints
const ACTIVE = "active"
const ACTIVE_RANGE = "activerange"
const ACTIVE_RANGE_LB = "activerange_lb"
const ACTIVE_RANGE_UB = "activerange_ub"
const COMMITMENT = "commitment"
const DURATION = "duration"
const DURATION_DOWN = "duration_dn"
const DURATION_UP = "duration_up"
const ENERGY_CAPACITY = "energy_capacity"
const ENERGY_LIMIT = "energy_limit"
const FEEDFORWARD = "FF"
const FEEDFORWARD_UB = "FF_ub"
const FEEDFORWARD_BIN = "FF_bin"
const FEEDFORWARD_INTEGRAL_LIMIT = "FF_integral"
const FLOW_LIMIT = "FlowLimit"
const FLOW_LIMIT_FROM_TO = "FlowLimitFT"
const FLOW_LIMIT_TO_FROM = "FlowLimitTF"
const FLOW_REACTIVE_POWER_FROM_TO = "FqFT"
const FLOW_REACTIVE_POWER_TO_FROM = "FqTF"
const FLOW_ACTIVE_POWER_FROM_TO = "FpFT"
const FLOW_ACTIVE_POWER_TO_FROM = "FpTF"
const FLOW_ACTIVE_POWER = "Fp"
const FLOW_REACTIVE_POWER = "Fq"
const INPUT_POWER_RANGE = "inputpower_range"
const OUTPUT_POWER_RANGE = "outputpower_range"
const RAMP = "ramp"
const RAMP_DOWN = "ramp_dn"
const RAMP_UP = "ramp_up"
const RATE_LIMIT = "RateLimit"
const RATE_LIMIT_FT = "RateLimitFT"
const RATE_LIMIT_TF = "RateLimitTF"
const REACTIVE = "reactive"
const REACTIVE_RANGE = "reactiverange"
const REQUIREMENT = "requirement"
const INFLOW_RANGE = "inflowrange"
const ACTIVE_RANGE_IC = "active_range_ic"
const START_TYPE = "start_type"
const STARTUP_TIMELIMIT = "startup_timelimit"
const STARTUP_TIMELIMIT_WARM = "startup_timelimit_warm"
const STARTUP_TIMELIMIT_HOT = "startup_timelimit_warm"
const STARTUP_INITIAL_CONDITION = "startup_initial_condition"
const STARTUP_INITIAL_CONDITION_UB = "startup_initial_condition_ub"
const STARTUP_INITIAL_CONDITION_LB = "startup_initial_condition_lb"
const MUST_RUN = "must_run"
const MUST_RUN_LB = "must_run_lb"
const NODAL_BALANCE_ACTIVE = "nodal_balance_active"
const NODAL_BALANCE_REACTIVE = "nodal_balance_reactive"
