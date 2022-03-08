########################### Thermal Generation Formulations ################################
abstract type AbstractThermalFormulation <: AbstractDeviceFormulation end
abstract type AbstractThermalDispatchFormulation <: AbstractThermalFormulation end
abstract type AbstractThermalUnitCommitment <: AbstractThermalFormulation end

abstract type AbstractStandardUnitCommitment <: AbstractThermalUnitCommitment end
abstract type AbstractCompactUnitCommitment <: AbstractThermalUnitCommitment end

struct ThermalBasicUnitCommitment <: AbstractStandardUnitCommitment end
struct ThermalStandardUnitCommitment <: AbstractStandardUnitCommitment end
struct ThermalBasicDispatch <: AbstractThermalDispatchFormulation end
struct ThermalStandardDispatch <: AbstractThermalDispatchFormulation end
struct ThermalDispatchNoMin <: AbstractThermalDispatchFormulation end

struct ThermalMultiStartUnitCommitment <: AbstractCompactUnitCommitment end
struct ThermalCompactUnitCommitment <: AbstractCompactUnitCommitment end
struct ThermalBasicCompactUnitCommitment <: AbstractCompactUnitCommitment end
struct ThermalCompactDispatch <: AbstractThermalDispatchFormulation end
