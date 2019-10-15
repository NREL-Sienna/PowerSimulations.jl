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
const MOPFM = MathOptFormat.MOF.Model()

#Type Alias for JuMP and PJ containers
const JuMPExpressionMatrix = Matrix{<:JuMP.AbstractJuMPScalar}
const PGAE{V} = PJ.ParametrizedGenericAffExpr{Float64, V} where V<:JuMP.AbstractVariableRef
const GAE{V} = JuMP.GenericAffExpr{Float64, V} where V<:JuMP.AbstractVariableRef
const JuMPAffineExpressionArray = Matrix{GAE{V}} where V<:JuMP.AbstractVariableRef
const JuMPConstraintArray = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}
const JuMPParamArray = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}
const DSDA = Dict{Symbol, JuMP.Containers.DenseAxisArray}
const Parameter = ParameterJuMP.ParameterRef
export Parameter
