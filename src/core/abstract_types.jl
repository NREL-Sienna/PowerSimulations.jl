########################### Abstract Types for Model Construction ##########################

abstract type AbstractModelContainer end

abstract type OptimizationContainerKey end

abstract type VariableType end
abstract type ConstraintType end
abstract type AuxVariableType end
abstract type ParameterType end
abstract type InitialConditionType end

const _DELIMITER = "_"

function get_entry_type_module(key::OptimizationContainerKey)
    return parentmodule(get_entry_type(key))
end

function get_component_type_module(key::OptimizationContainerKey)
    return parentmodule(get_component_type(key))
end

function encode_key(key::OptimizationContainerKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

function encode_symbol(
    ::Type{T},
    ::Type{U},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: Union{PSY.Component, PSY.System}, U}
    meta_ = isempty(meta) ? meta : _DELIMITER * meta
    T_ = replace(replace(IS.strip_module_name(T), "{" => _DELIMITER), "}" => "")
    return Symbol("$(IS.strip_module_name(string(U)))$(_DELIMITER)$(T_)" * meta_)
end

function check_meta_chars(meta)
    # Underscores in this field will prevent us from being able to decode keys.
    if occursin(_DELIMITER, meta)
        throw(IS.InvalidValue("'$_DELIMITER' is not allowed in meta"))
    end
end

"""
Abstract type for Device Formulations (a.k.a Models)

# Example
```julia
import PowerSimulations
const PSI = PowerSimulations
struct MyCustomFormulation <: PSI.AbstractDeviceFormulation
```
"""
abstract type AbstractDeviceFormulation end

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

abstract type AbstractAffectFeedForward end

abstract type AbstractCache end
abstract type FeedForwardChronology end

get_trigger(val::FeedForwardChronology) = val.trigger

abstract type InitialConditionChronology end
