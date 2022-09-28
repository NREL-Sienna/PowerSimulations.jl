"""
Abstract type for Device Formulations (a.k.a Models)

# Example

import PowerSimulations
const PSI = PowerSimulations
struct MyCustomDeviceFormulation <: PSI.AbstractDeviceFormulation
"""
abstract type AbstractDeviceFormulation end

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

############################# Electric Load Formulations ###################################
abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end
abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end
struct StaticPowerLoad <: AbstractLoadFormulation end
struct InterruptiblePowerLoad <: AbstractControllablePowerLoadFormulation end
struct DispatchablePowerLoad <: AbstractControllablePowerLoadFormulation end

########################### Hybrid Generation Formulations ################################
abstract type AbstractHybridFormulation <: AbstractDeviceFormulation end
abstract type AbstractStandardHybridFormulation <: AbstractHybridFormulation end
struct BasicHybridDispatch <: AbstractHybridFormulation end
struct StandardHybridDispatch <: AbstractStandardHybridFormulation end

############################ Hydro Generation Formulations #################################
abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end
abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end
abstract type AbstractHydroUnitCommitment <: AbstractHydroFormulation end
abstract type AbstractHydroReservoirFormulation <: AbstractHydroDispatchFormulation end

"""
Formulation type to add injection variables constrained by a maximum injection time series for `HydroGen`
"""
struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end

"""
Formulation type to add injection variables constrained by total energy production budget defined with a time series for `HydroGen`
"""
struct HydroDispatchReservoirBudget <: AbstractHydroReservoirFormulation end

"""
Formulation type to constrain hydropower production with a representation of the energy storage capacity and water inflow time series of a reservoir for `HydroGen`
"""
struct HydroDispatchReservoirStorage <: AbstractHydroReservoirFormulation end

"""
Formulation type to constrain energy production from pumped storage with a representation of the energy storage capacity of upper and lower reservoirs and water inflow time series of upper reservoir and outflow time series of lower reservoir for `HydroPumpedStorage`
"""
struct HydroDispatchPumpedStorage <: AbstractHydroReservoirFormulation end

"""
Formulation type to add commitment and injection variables constrained by a maximum injection time series for `HydroGen`
"""
struct HydroCommitmentRunOfRiver <: AbstractHydroUnitCommitment end

"""
Formulation type to add commitment and injection variables constrained by total energy production budget defined with a time series for `HydroGen`
"""
struct HydroCommitmentReservoirBudget <: AbstractHydroUnitCommitment end

"""
Formulation type to constrain hydropower production with unit commitment variables and a representation of the energy storage capacity and water inflow time series of a reservoir for `HydroGen`
"""
struct HydroCommitmentReservoirStorage <: AbstractHydroUnitCommitment end

############################ Regulation Device Formulations ################################
abstract type AbstractRegulationFormulation <: AbstractDeviceFormulation end
struct ReserveLimitedRegulation <: AbstractRegulationFormulation end
struct DeviceLimitedRegulation <: AbstractRegulationFormulation end

########################### Renewable Generation Formulations ##############################
abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end
abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end

"""
Formulation type to add injection variables constrained by a maximum injection time series for `RenewableGen`
"""
struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end

"""
Formulation type to add real and reactive injection variables with constant power factor with maximum real power injections constrained by a time series for `RenewableGen`
"""
struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

############################ Storage Generation Formulations ###############################
abstract type AbstractStorageFormulation <: AbstractDeviceFormulation end
abstract type AbstractEnergyManagement <: AbstractStorageFormulation end
struct BookKeeping <: AbstractStorageFormulation end
struct BatteryAncillaryServices <: AbstractStorageFormulation end
struct EnergyTarget <: AbstractEnergyManagement end

"""
Abstract type for Branch Formulations (a.k.a Models)

# Example
import PowerSimulations
const PSI = PowerSimulations
struct MyCustomBranchFormulation <: PSI.AbstractDeviceFormulation
"""
# Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

############################### AC Branch Formulations #####################################
"""
Branch type to add unbounded flow variables and use flow constraints
"""
struct StaticBranch <: AbstractBranchFormulation end
"""
Branch type to add bounded flow variables and use flow constraints
"""
struct StaticBranchBounds <: AbstractBranchFormulation end
"""
Branch type to avoid flow constraints
"""
struct StaticBranchUnbounded <: AbstractBranchFormulation end

############################### DC Branch Formulations #####################################
abstract type AbstractDCLineFormulation <: AbstractBranchFormulation end
struct HVDCUnbounded <: AbstractDCLineFormulation end
struct HVDCLossless <: AbstractDCLineFormulation end
struct HVDCDispatch <: AbstractDCLineFormulation end
# Not Implemented
# struct VoltageSourceDC <: AbstractDCLineFormulation end

############################## Network Model Formulations ##################################
# These formulations are taken directly from PowerModels

abstract type AbstractPTDFModel <: PM.AbstractDCPModel end
struct StandardPTDFModel <: AbstractPTDFModel end
struct PTDFPowerModel <: AbstractPTDFModel end

struct CopperPlatePowerModel <: PM.AbstractActivePowerModel end
struct AreaBalancePowerModel <: PM.AbstractActivePowerModel end

#================================================
    # exact non-convex models
    ACPPowerModel, ACRPowerModel, ACTPowerModel

    # linear approximations
    DCPPowerModel, NFAPowerModel

    # quadratic approximations
    DCPLLPowerModel, LPACCPowerModel

    # quadratic relaxations
    SOCWRPowerModel, SOCWRConicPowerModel,
    SOCBFPowerModel, SOCBFConicPowerModel,
    QCRMPowerModel, QCLSPowerModel,

    # sdp relaxations
    SDPWRMPowerModel, SparseSDPWRMPowerModel
================================================#

##### Exact Non-Convex Models #####
import PowerModels: ACPPowerModel

import PowerModels: ACRPowerModel

import PowerModels: ACTPowerModel

##### Linear Approximations #####
import PowerModels: DCPPowerModel

import PowerModels: NFAPowerModel

##### Quadratic Approximations #####
import PowerModels: DCPLLPowerModel

import PowerModels: LPACCPowerModel

##### Quadratic Relaxations #####
import PowerModels: SOCWRPowerModel

import PowerModels: SOCWRConicPowerModel

import PowerModels: QCRMPowerModel

import PowerModels: QCLSPowerModel

abstract type AbstractServiceFormulation end

abstract type AbstractAGCFormulation <: AbstractServiceFormulation end

struct PIDSmoothACE <: AbstractAGCFormulation end

abstract type AbstractReservesFormulation <: AbstractServiceFormulation end

struct GroupReserve <: AbstractReservesFormulation end
struct RangeReserve <: AbstractReservesFormulation end
struct StepwiseCostReserve <: AbstractReservesFormulation end
struct RampReserve <: AbstractReservesFormulation end
struct NonSpinningReserve <: AbstractReservesFormulation end
