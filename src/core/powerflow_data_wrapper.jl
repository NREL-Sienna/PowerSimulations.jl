mutable struct PowerFlowEvaluationData{T <: PFS.PowerFlowData}
    power_flow_data::T
    injection_key_map::Dict{<:OptimizationContainerKey, Dict{String, Int}}
end
