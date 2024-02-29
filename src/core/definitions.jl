#################################################################################
# Type Alias for long type signatures
const MinMax = NamedTuple{(:min, :max), NTuple{2, Float64}}
const NamedMinMax = Tuple{String, MinMax}
const UpDown = NamedTuple{(:up, :down), NTuple{2, Float64}}
const InOut = NamedTuple{(:in, :out), NTuple{2, Float64}}
const StartUpStages = NamedTuple{(:hot, :warm, :cold), NTuple{3, Float64}}

const BUILD_PROBLEMS_TIMER = TimerOutputs.TimerOutput()
const RUN_OPERATION_MODEL_TIMER = TimerOutputs.TimerOutput()
const RUN_SIMULATION_TIMER = TimerOutputs.TimerOutput()

# Type Alias for JuMP containers
const GAE = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}
const JuMPAffineExpressionArray = Matrix{GAE}
const JuMPAffineExpressionVector = Vector{GAE}
const JuMPConstraintArray = DenseAxisArray{JuMP.ConstraintRef}
const JuMPVariableMatrix = DenseAxisArray{
    JuMP.VariableRef,
    2,
    Tuple{Vector{String}, UnitRange{Int64}},
    Tuple{
        JuMP.Containers._AxisLookup{Dict{String, Int64}},
        JuMP.Containers._AxisLookup{Tuple{Int64, Int64}},
    },
}
const JuMPFloatMatrix = DenseAxisArray{Float64, 2}
const JuMPFloatArray = DenseAxisArray{Float64}
const JuMPVariableArray = DenseAxisArray{JuMP.VariableRef}

const TwoTerminalHVDCTypes = Union{PSY.TwoTerminalHVDCLine, PSY.TwoTerminalVSCDCLine}
# Settings constants
const UNSET_HORIZON = 0
const UNSET_INI_TIME = Dates.DateTime(0)

# Tolerance of comparisons
# MIP gap tolerances in most solvers are set to 1e-4
const ABSOLUTE_TOLERANCE = 1.0e-3
const BALANCE_SLACK_COST = 1e6
const CONSTRAINT_VIOLATION_SLACK_COST = 2e5
const SERVICES_SLACK_COST = 1e5
const COST_EPSILON = 1e-3
const MISSING_INITIAL_CONDITIONS_TIME_COUNT = 999.0
const SECONDS_IN_MINUTE = 60.0
const MINUTES_IN_HOUR = 60.0
const SECONDS_IN_HOUR = 3600.0
const MAX_START_STAGES = 3
const OBJECTIVE_FUNCTION_POSITIVE = 1.0
const OBJECTIVE_FUNCTION_NEGATIVE = -1.0
const INITIALIZATION_PROBLEM_HORIZON = 3
# The DEFAULT_RESERVE_COST value is used to avoid degeneracy of the solutions, reserve cost isn't provided.
const DEFAULT_RESERVE_COST = 1.0
const KiB = 1024
const MiB = KiB * KiB
const GiB = MiB * KiB

const PSI_NAME_DELIMITER = "__"

const M_VALUE = 1e6

const NO_SERVICE_NAME_PROVIDED = ""
const UPPER_BOUND = "ub"
const LOWER_BOUND = "lb"
const MAX_OPTIMIZE_TRIES = 2

# File Names definitions
const PROBLEM_SERIALIZATION_FILENAME = "operation_problem.bin"
const PROBLEM_LOG_FILENAME = "operation_problem.log"
const HASH_FILENAME = "check.sha256"
const SIMULATION_SERIALIZATION_FILENAME = "simulation.bin"
const SIMULATION_LOG_FILENAME = "simulation.log"
const REQUIRED_RECORDERS = (:simulation_status, :execution)
const KNOWN_SIMULATION_PATHS = [
    "data_store",
    "logs",
    "models_json",
    "problems",
    "recorder",
    "results",
    "simulation_files",
    "simulation_partitions",
]
const RESULTS_DIR = "results"

# Enums
IS.@scoped_enum(BuildStatus, IN_PROGRESS = -1, BUILT = 0, FAILED = 1, EMPTY = 2,)
IS.@scoped_enum(
    RunStatus,
    NOT_READY = -2,
    READY = -1,
    SUCCESSFUL = 0,
    RUNNING = 1,
    FAILED = 2,
)
IS.@scoped_enum(SOSStatusVariable, NO_VARIABLE = 1, PARAMETER = 2, VARIABLE = 3,)

IS.@scoped_enum(COMPACT_PWL_STATUS, VALID = 1, INVALID = 2, UNDETERMINED = 3)

const ENUMS = (BuildStatus, RunStatus, SOSStatusVariable)

const ENUM_MAPPINGS = Dict()

for enum in ENUMS
    ENUM_MAPPINGS[enum] = Dict()
    for value in instances(enum)
        ENUM_MAPPINGS[enum][lowercase(string(value))] = value
    end
end

"""
Get the enum value for the string. Case insensitive.
"""
function get_enum_value(enum, value::String)
    if !haskey(ENUM_MAPPINGS, enum)
        throw(ArgumentError("enum=$enum is not valid"))
    end

    val = lowercase(value)
    if !haskey(ENUM_MAPPINGS[enum], val)
        throw(ArgumentError("enum=$enum does not have value=$val"))
    end

    return ENUM_MAPPINGS[enum][val]
end

Base.convert(::Type{BuildStatus}, val::String) = get_enum_value(BuildStatus, val)
Base.convert(::Type{RunStatus}, val::String) = get_enum_value(RunStatus, val)
Base.convert(::Type{SOSStatusVariable}, x::String) = get_enum_value(SOSStatusVariable, x)

# Store const definitions
# Update src/simulation/simulation_store_common.jl with any changes.
const STORE_CONTAINER_DUALS = :duals
const STORE_CONTAINER_PARAMETERS = :parameters
const STORE_CONTAINER_VARIABLES = :variables
const STORE_CONTAINER_AUX_VARIABLES = :aux_variables
const STORE_CONTAINER_EXPRESSIONS = :expressions
const STORE_CONTAINERS = (
    STORE_CONTAINER_DUALS,
    STORE_CONTAINER_PARAMETERS,
    STORE_CONTAINER_VARIABLES,
    STORE_CONTAINER_AUX_VARIABLES,
    STORE_CONTAINER_EXPRESSIONS,
)
