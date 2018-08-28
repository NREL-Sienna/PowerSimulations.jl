abstract type AbstractDCPowerModel <: PM.AbstractPowerFormulation end

abstract type CopperPlatePowerModel <: PM.AbstractPowerFormulation end

abstract type AbstractFlowForm <: AbstractDCPowerModel end

abstract type StandardPTDFForm <: AbstractFlowForm end

abstract type StandardPTDFLossesForm <: AbstractFlowForm end

#This line is from PowerModels, needs to be removed later
abstract type DCPlosslessForm <: PM.AbstractDCPForm end

