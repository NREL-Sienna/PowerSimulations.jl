########################### Abstract Types for Model Construction ##########################

abstract type AbstractModelContainer end

abstract type VariableType end
abstract type ConstraintType end
abstract type AuxVariableType end
abstract type ParameterType end
abstract type InitialConditionType end
abstract type ExpressionType end

"""
Abstract type for Device Formulations (a.k.a Models)

# Example
```julia
import PowerSimulations
const PSI = PowerSimulations
struct MyCustomDeviceFormulation <: PSI.AbstractDeviceFormulation
```
"""
abstract type AbstractDeviceFormulation end

"""
Abstract type for Branch Formulations (a.k.a Models)

# Example
```julia
import PowerSimulations
const PSI = PowerSimulations
struct MyCustomBranchFormulation <: PSI.AbstractDeviceFormulation
```
"""
# Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

"""
Abstract type for Decision Model and Emulation Model. OperationModel structs are parameterized with DecisionProblem or Emulation Problem structs
"""
abstract type OperationModel end

#TODO: Document the required interfaces for custom types
"""
Abstract type for Decision Problems

# Example
```julia
import PowerSimulations
const PSI = PowerSimulations
struct MyCustomProblem <: PSI.DecisionProblem
```
"""
abstract type DecisionProblem end

"""
Abstract type for Emulation Problems

# Example
```julia
import PowerSimulations
const PSI = PowerSimulations
struct MyCustomEmulator <: PSI.EmulationProblem
```
"""
abstract type EmulationProblem end

"Optimization Container construction stage"
abstract type ConstructStage end

struct ArgumentConstructStage end
struct ModelConstructStage end

abstract type PSIResults <: IS.Results end

################################ Abstract Types for Simulation #############################
"""
Provides storage of simulation data
"""
abstract type SimulationStore end

# Required methods:
# - open_store
# - Base.isopen(store::SimulationStore)
# - Base.close(store::SimulationStore)
# - Base.flush(store::SimulationStore)
# - get_params(store::SimulationStore)
# - initialize_problem_storage!
# - list_fields(store::SimulationStore, problem::Symbol, container_type::Symbol)
# - list_problems(store::SimulationStore)
# - log_cache_hit_percentages(store::SimulationStore)
# - write_result!
# - read_result!
# - write_optimizer_stats!
# - read_problem_optimizer_stats

abstract type AbstractModelOptimizerResults end

# Required methods: TBD

abstract type AbstractAffectFeedForward end

get_device_type(x::AbstractAffectFeedForward) = x.device_type

abstract type AbstractCache end
abstract type FeedForwardChronology end

get_trigger(val::FeedForwardChronology) = val.trigger

abstract type InitialConditionChronology end
