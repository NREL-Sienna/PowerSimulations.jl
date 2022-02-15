"""
Abstract type for Device Formulations (a.k.a Models)

# Example

import PowerSimulations
const PSI = PowerSimulations
struct MyCustomDeviceFormulation <: PSI.AbstractDeviceFormulation
"""
abstract type AbstractDeviceFormulation end

"""
Abstract type for Branch Formulations (a.k.a Models)

# Example
import PowerSimulations
const PSI = PowerSimulations
struct MyCustomBranchFormulation <: PSI.AbstractDeviceFormulation
"""
# Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end
