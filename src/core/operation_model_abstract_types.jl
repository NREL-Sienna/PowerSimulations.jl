"""
Abstract type for Decision Model and Emulation Model. OperationModel structs are parameterized with DecisionProblem or Emulation Problem structs
"""
abstract type OperationModel end

#TODO: Document the required interfaces for custom types
"""
Abstract type for Decision Problems

# Example

import PowerSimulations as PSI
struct MyCustomProblem <: PSI.DecisionProblem
"""
abstract type DecisionProblem end

"""
Abstract type for Emulation Problems

# Example

import PowerSimulations as PSI
struct MyCustomEmulator <: PSI.EmulationProblem
"""
abstract type EmulationProblem end
