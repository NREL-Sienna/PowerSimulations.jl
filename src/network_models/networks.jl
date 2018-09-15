#First Level Abstraction

abstract type AbstractACPowerModel <: PM.AbstractPowerFormulation end

const AbstractDCPowerModel = Union{PM.AbstractDCPForm, PM.AbstractDCPLLForm} #Adopt from PowerModels, LL -> Line Losses

abstract type CopperPlatePowerModel <: PM.AbstractPowerFormulation end

#Second Level Abstraction AC

abstract type StandardAC <: AbstractACPowerModel end

#Second Level Abstraction DC 

##This line is from PowerModels, needs to be removed later

abstract type DCPlosslessForm <: PM.AbstractDCPForm end

#abstract type StandardDCPLLForm<: PM.AbstractDCPLLForm end

abstract type AbstractFlowForm <: PM.AbstractDCPForm end

abstract type AbstractFlowLLForm <: PM.AbstractDCPLLForm end

#Third Level of Abstraction.

abstract type StandardPTDF <: AbstractFlowForm end    

abstract type StandardPTDFLL <: AbstractFlowLLForm end

abstract type StandardNetFlow <: AbstractFlowForm end    

abstract type StandardNetFlowLL <: AbstractFlowLLForm end