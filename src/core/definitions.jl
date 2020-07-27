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
