### Network models

struct CopperPlatePowerModel <: PM.AbstractActivePowerModel end
struct AreaBalancePowerModel <: PM.AbstractActivePowerModel end
struct StandardPTDFModel <: PM.AbstractDCPModel end
struct PTDFPowerModel <: PM.AbstractDCPModel end

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
