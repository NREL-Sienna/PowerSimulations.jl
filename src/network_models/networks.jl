abstract type AbstractDCPowerModel <: PM.AbstractPowerFormulation end

abstract type CopperPlatePowerModel <: PM.AbstractPowerFormulation end

abstract type AbstractFlowForm <: AbstractDCPowerModel end

abstract type StandardPTDFLLForm <: AbstractFlowForm end

abstract type StandardPTDFLossesForm <: AbstractFlowForm end

const PTDF = StandardPTDFLLForm

const PTDFLosses = StandardPTDFLossesForm