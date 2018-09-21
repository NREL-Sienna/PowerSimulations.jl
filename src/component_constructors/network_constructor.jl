function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel}

    copperplatebalance(m, netinjection, sys.time_periods)

end

function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: AbstractDCPowerModel}

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys)
    end

    nodalflowbalance(m, netinjection, system_formulation, sys)    
    
end


function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: Union{DCAngleLLForm, DCAngleForm}}

    anglevariables(m, system_formulation, sys)

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys)
    end

    nodalflowbalance(m, netinjection, system_formulation, sys)    
    
end


function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; kwargs...) where {S <: AbstractACPowerModel}

    anglevariables(m, system_formulation, sys)

    voltagevariables(m, system_formulation, sys)

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys)
    end

    nodalflowbalance(m, netinjection, system_formulation, sys)

end
