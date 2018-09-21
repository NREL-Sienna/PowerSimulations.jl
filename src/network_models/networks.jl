#First Level Abstraction

const AbstractACPowerModel = Union{PM.AbstractACPForm, PM.AbstractACRForm}

const AbstractDCPowerModel = Union{PM.AbstractDCPForm, PM.AbstractDCPLLForm} #Adopt from PowerModels, LL -> Line Losses

abstract type CopperPlatePowerModel <: PM.AbstractPowerFormulation end

#Second Level Abstraction AC

#adopted from PowerModels

const StandardAC = PM.StandardACPForm

#Second Level Abstraction DC 

##This line is from PowerModels, needs to be removed later

abstract type DCAngleForm <: PM.AbstractDCPForm end

abstract type DCAngleLLForm <: PM.AbstractDCPLLForm end

#abstract type StandardDCPLLForm<: PM.AbstractDCPLLForm end

abstract type AbstractFlowForm <: PM.AbstractDCPForm end

abstract type AbstractFlowLLForm <: PM.AbstractDCPLLForm end

#Third Level of Abstraction.

abstract type StandardPTDF <: AbstractFlowForm end    

abstract type StandardPTDFLL <: AbstractFlowLLForm end

abstract type StandardNetFlow <: AbstractFlowForm end    

abstract type StandardNetFlowLL <: AbstractFlowLLForm end