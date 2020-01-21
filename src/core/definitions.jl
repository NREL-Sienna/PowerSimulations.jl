#################################################################################
#Type Alias for long type signatures
const MinMax = NamedTuple{(:min, :max), NTuple{2, Float64}}
const NamedMinMax = Tuple{String, MinMax}
const UpDown = NamedTuple{(:up, :down), NTuple{2, Float64}}
const InOut = NamedTuple{(:in, :out), NTuple{2, Float64}}

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

#Type Alias for JuMP and PJ containers
const JuMPExpressionMatrix = Matrix{<:JuMP.AbstractJuMPScalar}
const PGAE{V} = PJ.ParametrizedGenericAffExpr{Float64, V} where V<:JuMP.AbstractVariableRef
const GAE{V} = JuMP.GenericAffExpr{Float64, V} where V<:JuMP.AbstractVariableRef
const JuMPAffineExpressionArray = Matrix{GAE{V}} where V<:JuMP.AbstractVariableRef
const JuMPAffineExpressionVector = Vector{GAE{V}} where V<:JuMP.AbstractVariableRef
const JuMPConstraintArray = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}
const JuMPParamArray = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}
const DSDA = Dict{Symbol, JuMP.Containers.DenseAxisArray}

# Tolerance of comparisons
const ComparisonTolerance = 1.0e-10

const OPERATIONS_ACCEPTED_KWARGS = [
                                    :horizon,
                                    :initial_conditions,
                                    :use_forecast_data,
                                    :use_parameters,
                                    :JuMPmodel,
                                    :optimizer,
                                    :PTDF,
                                    ]
const SIMULATION_BUILD_KWARGS = [
                                 :system_to_file,
                                 :PTDF_matrices,
                                 ]

# The constants below are strings instead of enums because there is a requirement that users
# should be able to define their own without changing PowerSimulations.


# Variables
const FLOW_REAL_POWER = "Fp"
const REAL_POWER = "P"
const REACTIVE_POWER = "Q"
const P_OUT = "Pout"
const P_IN = "Pin"
const R = "R"
const E = "E"
const ON = "On"
const START = "Start"
const STOP = "Stop"
const THETA = "theta"
const VM = "Vm"

# Constraints
const ACTIVE = "active"
const ACTIVE_RANGE = "activerange"
const ACTIVE_RANGE_LB = "activerange_lb"
const ACTIVE_RANGE_UB = "activerange_ub"
const COMMITMENT = "commitment"
const DURATION = "duration"
const DURATION_UP = "duration_up"
const DURATION_DOWN = "duration_dn"
const ENERGY_LIMIT = "energy_limit"
const RAMP = "ramp"
const RAMP_UP = "ramp_up"
const RAMP_DOWN = "ramp_dn"
const RATE_LIMIT = "RateLimit"
const RATE_LIMIT_FT = "RateLimitFT"
const RATE_LIMIT_TF = "RateLimitTF"
const REACTIVE = "reactive"
const REACTIVE_RANGE = "reactiverange"
const FP_FT = "FpFT"
const FP_TF = "FpTF"
const FQ_FT = "FqFT"
const FQ_TF = "FqTF"
const FEED_FORWARD = "FF"
const FEED_FORWARD_BIN = "FFbin"
const REQUIREMENT = "requirement"

# Parameters
const ACTIVE_POWER = "activepower"
const ENERGY = "energy"
