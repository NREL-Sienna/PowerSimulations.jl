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
Formulation type to enable standard unit commitment with intertemporal constraints and simplified startup profiles
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
Formulation type to enable basic dispatch without any intertemporal constraints and relaxed minimum generation. *May not work with non-convex PWL cost definitions*
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
Formulation type to add a time series parameter for non-dispatchable `ElectricLoad` withdrawals to power balance constraints
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

"""
Abstract type for Branch Formulations (a.k.a Models)

# Example
import PowerSimulations
const PSI = PowerSimulations
struct MyCustomBranchFormulation <: PSI.AbstractDeviceFormulation
"""
# Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

############################### AC/DC Branch Formulations #####################################
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
abstract type AbstractTwoTerminalDCLineFormulation <: AbstractBranchFormulation end
"""
Branch type to avoid flow constraints
"""
struct HVDCTwoTerminalUnbounded <: AbstractTwoTerminalDCLineFormulation end
"""
Branch type to represent lossless power flow on DC lines
"""
struct HVDCTwoTerminalLossless <: AbstractTwoTerminalDCLineFormulation end
"""
Branch type to represent lossy power flow on DC lines
"""
struct HVDCTwoTerminalDispatch <: AbstractTwoTerminalDCLineFormulation end
# Not Implemented
# struct VoltageSourceDC <: AbstractTwoTerminalDCLineFormulation end

############################### AC/DC Converter Formulations #####################################
abstract type AbstractConverterFormulation <: AbstractDeviceFormulation end

"""
LossLess InterconnectingConverter Model
"""
struct LossLessConverter <: AbstractConverterFormulation end

"""
LossLess Line Abstract Model
"""
struct LossLessLine <: AbstractBranchFormulation end

############################## Network Model Formulations ##################################
# These formulations are taken directly from PowerModels

abstract type AbstractPTDFModel <: PM.AbstractDCPModel end
"""
Linear active power approximation using the power transfer distribution factor [PTDF](https://nrel-sienna.github.io/PowerNetworkMatrices.jl/stable/tutorials/tutorial_PTDF_matrix/) matrix.
"""
struct PTDFPowerModel <: AbstractPTDFModel end
"""
Infinite capacity approximation of network flow to represent entire system with a single node.
"""
struct CopperPlatePowerModel <: PM.AbstractActivePowerModel end
"""
Approximation to represent inter-area flow with each area represented as a single node.
"""
struct AreaBalancePowerModel <: PM.AbstractActivePowerModel end
"""
Linear active power approximation using the power transfer distribution factor [PTDF](https://nrel-sienna.github.io/PowerNetworkMatrices.jl/stable/tutorials/tutorial_PTDF_matrix/) matrix. Balacing areas independently.
"""
struct AreaPTDFPowerModel <: AbstractPTDFModel end

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

"""
Abstract type for Service Formulations (a.k.a Models)

# Example

import PowerSimulations
const PSI = PowerSimulations
struct MyServiceFormulation <: PSI.AbstractServiceFormulation
"""
abstract type AbstractServiceFormulation end

abstract type AbstractReservesFormulation <: AbstractServiceFormulation end

abstract type AbstractAGCFormulation <: AbstractServiceFormulation end

struct PIDSmoothACE <: AbstractAGCFormulation end

"""
Struct to add reserves to be larger than a specified requirement for an aggregated collection of services
"""
struct GroupReserve <: AbstractReservesFormulation end

"""
Struct for to add reserves to be larger than a specified requirement
"""
struct RangeReserve <: AbstractReservesFormulation end
"""
Struct for to add reserves to be larger than a variable requirement depending of costs
"""
struct StepwiseCostReserve <: AbstractReservesFormulation end
"""
Struct to add reserves to be larger than a specified requirement, with ramp constraints
"""
struct RampReserve <: AbstractReservesFormulation end
"""
Struct to add non spinning reserve requirements larger than specified requirement
"""
struct NonSpinningReserve <: AbstractReservesFormulation end
"""
Struct to add a constant maximum transmission flow for specified interface
"""
struct ConstantMaxInterfaceFlow <: AbstractServiceFormulation end
