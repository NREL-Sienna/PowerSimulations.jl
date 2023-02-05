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
"""
Formulation type to enable basic unit commitment representation without any intertemporal (ramp, min on/off time) constraints
"""
struct ThermalBasicUnitCommitment <: AbstractStandardUnitCommitment end
"""
Formulaiton type to enable standard unit commitment with intertemporal constraints and simplified startup profiles
"""
struct ThermalStandardUnitCommitment <: AbstractStandardUnitCommitment end
"""
Formulation type to enable basic dispatch without any intertemporal (ramp) constraints
"""
struct ThermalBasicDispatch <: AbstractThermalDispatchFormulation end
"""
Formulation type to enable standard dispatch with a range and enforce intertemporal ramp constraints
"""
struct ThermalStandardDispatch <: AbstractThermalDispatchFormulation end
"""
Formulation type to enable basic dispatch without any intertemporal constraints and relaxed minimum generation. *may not work with PWL cost definitions*
"""
struct ThermalDispatchNoMin <: AbstractThermalDispatchFormulation end
"""
Formulation type to enable pg-lib commitment formulation with startup/shutdown profiles
"""
struct ThermalMultiStartUnitCommitment <: AbstractCompactUnitCommitment end
"""
Formulation type to enable thermal compact commitment
"""
struct ThermalCompactUnitCommitment <: AbstractCompactUnitCommitment end
"""
Formulation type to enable thermal compact commitment without intertemporal (ramp, min on/off time) constraints
"""
struct ThermalBasicCompactUnitCommitment <: AbstractCompactUnitCommitment end
"""
Formulation type to enable thermal compact dispatch
"""
struct ThermalCompactDispatch <: AbstractThermalDispatchFormulation end

############################# Electric Load Formulations ###################################
abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end
abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end

"""
Formulation type to add a time series paraemter for non-dispatchable `ElectricLoad` withdrawls to power balance constraints
"""
struct StaticPowerLoad <: AbstractLoadFormulation end

"""
Formulation type to enable (binary) load interruptions
"""
struct PowerLoadInterruption <: AbstractControllablePowerLoadFormulation end

"""
Formulation type to enable (continuous) load interruption dispatch
"""
struct PowerLoadDispatch <: AbstractControllablePowerLoadFormulation end

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

"""
Formulation type to add basic storage formulation. With `attributes=Dict("reservation"=>true)` the formulation is augmented
with abinary variable to prevent simultanious charging and discharging
"""
struct BookKeeping <: AbstractStorageFormulation end
"""
Formulation type to add storage formulation than can provide ancillary services. With `attributes=Dict("reservation"=>true)` the formulation is augmented
with abinary variable to prevent simultanious charging and discharging
"""
struct BatteryAncillaryServices <: AbstractStorageFormulation end
"""
Formulation type to add storage formulation that respects end of horizon energy state of charge target. With `attributes=Dict("reservation"=>true)` the formulation is augmented
with abinary variable to prevent simultanious charging and discharging
"""
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
"""
Branch formulation for PhaseShiftingTransformer flow control
"""
struct PhaseAngleControl <: AbstractBranchFormulation end

############################### DC Branch Formulations #####################################
abstract type AbstractDCLineFormulation <: AbstractBranchFormulation end
"""
Branch type to avoid flow constraints
"""
struct HVDCP2PUnbounded <: AbstractDCLineFormulation end
"""
Branch type to represent lossless power flow on DC lines
"""
struct HVDCP2PLossless <: AbstractDCLineFormulation end
"""
Branch type to represent lossy power flow on DC lines
"""
struct HVDCP2PDispatch <: AbstractDCLineFormulation end
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
