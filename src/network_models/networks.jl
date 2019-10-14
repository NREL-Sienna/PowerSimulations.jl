struct CopperPlatePowerModel <: PM.AbstractActivePowerModel  end
struct StandardPTDFModel <: PM.AbstractDCPModel end

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
export ACPPowerModel

import PowerModels: ACRPowerModel
export ACRPowerModel

import PowerModels: ACTPowerModel
export ACTPowerModel


##### Linear Approximations #####
import PowerModels: DCPPowerModel
export DCPPowerModel

import PowerModels: NFAPowerModel
export NFAPowerModel

##### Quadratic Approximations #####
import PowerModels: DCPLLPowerModel
export DCPLLPowerModel

import PowerModels: LPACCPowerModel
export LPACCPowerModel

##### Quadratic Relaxations #####
import PowerModels: SOCWRPowerModel
export SOCWRPowerModel

import PowerModels: SOCWRConicPowerModel
export SOCWRConicPowerModel

import PowerModels: QCRMPowerModel
export QCRMPowerModel

import PowerModels: QCLSPowerModel
export QCLSPowerModel
