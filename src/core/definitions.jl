#################################################################################
# Type Alias for long type signatures
const MinMax = NamedTuple{(:min, :max), NTuple{2, Float64}}
const NamedMinMax = Tuple{String, MinMax}
const UpDown = NamedTuple{(:up, :down), NTuple{2, Float64}}
const InOut = NamedTuple{(:in, :out), NTuple{2, Float64}}
const StartUpStages = NamedTuple{(:hot, :warm, :cold), NTuple{3, Float64}}

const BUILD_PROBLEMS_TIMER = TimerOutputs.TimerOutput()
const RUN_SIMULATION_TIMER = TimerOutputs.TimerOutput()

# Type Alias for JuMP and PJ containers
const JuMPExpressionMatrix = Matrix{<:JuMP.AbstractJuMPScalar}
const PGAE = PJ.ParametrizedGenericAffExpr{Float64, JuMP.VariableRef}
const GAE = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}
const JuMPAffineExpressionArray = Matrix{GAE}
const JuMPAffineExpressionVector = Vector{GAE}
const JuMPConstraintArray = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}
const JuMPVariableArray = JuMP.Containers.DenseAxisArray{JuMP.VariableRef}
const JuMPParamArray = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}
const DenseAxisArrayContainer = Dict{Symbol, JuMP.Containers.DenseAxisArray}

# Settings constants
const UNSET_HORIZON = 0
const UNSET_INI_TIME = Dates.DateTime(0)

# Tolerance of comparisons
# MIP gap tolerances in most solvers are set to 1e-4
const ABSOLUTE_TOLERANCE = 1.0e-3
const BALANCE_SLACK_COST = 1e6
const SERVICES_SLACK_COST = 1e5
const FEEDFORWARD_SLACK_COST = 1e5
const COST_EPSILON = 1e-3
const MISSING_INITIAL_CONDITIONS_TIME_COUNT = 999.0
const SECONDS_IN_MINUTE = 60.0
const MINUTES_IN_HOUR = 60.0
const SECONDS_IN_HOUR = 3600.0
const MAX_START_STAGES = 3
const OBJECTIVE_FUNCTION_POSITIVE = 1.0
const OBJECTIVE_FUNCTION_NEGATIVE = -1.0
# The DEFAULT_RESERVE_COST value is used to avoid degeneracy of the solutions, reseve cost isn't provided.
const DEFAULT_RESERVE_COST = 1.0e-4
const KiB = 1024
const MiB = KiB * KiB
const GiB = MiB * KiB

const UNSUPPORTED_POWERMODELS =
    [PM.SOCBFPowerModel, PM.SOCBFConicPowerModel, PM.IVRPowerModel]

const PSI_NAME_DELIMITER = "__"

const M_VALUE = 1e6

const NO_SERVICE_NAME_PROVIDED = ""

# File Names definitions
const PROBLEM_SERIALIZATION_FILENAME = "operations_problem.bin"
const PROBLEM_BUILD_LOG_FILENAME = "operations_problem_build.log"
const HASH_FILENAME = "check.sha256"
const SIMULATION_SERIALIZATION_FILENAME = "simulation.bin"
const SIMULATION_LOG_FILENAME = "simulation.log"
const REQUIRED_RECORDERS = (:simulation_status, :simulation)
const KNOWN_SIMULATION_PATHS = [
    "data_store",
    "logs",
    "models_json",
    "problems",
    "recorder",
    "results",
    "simulation_files",
]

# Enums
IS.@scoped_enum(BuildStatus, IN_PROGRESS = -1, BUILT = 0, FAILED = 1, EMPTY = 2,)
IS.@scoped_enum(RunStatus, READY = -1, SUCCESSFUL = 0, RUNNING = 1, FAILED = 2,)
IS.@scoped_enum(SOSStatusVariable, NO_VARIABLE = 1, PARAMETER = 2, VARIABLE = 3,)

const ENUMS = (BuildStatus, RunStatus, SOSStatusVariable)

const ENUM_MAPPINGS = Dict()

for enum in ENUMS
    ENUM_MAPPINGS[enum] = Dict()
    for value in instances(enum)
        ENUM_MAPPINGS[enum][lowercase(string(value))] = value
    end
end

"""Get the enum value for the string. Case insensitive."""
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
