function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: CopperPlatePowerModel}

    copperplatebalance(m, netinjection, sys.time_periods)

end

function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{StandardPTDF}, sys::PowerSystems.PowerSystem; args...)
    if :PTDF in keys(args)
        PTDF = args[:PTDF]
    else
        PTDF = nothing
    end

    if !isa(PTDF,PTDFArray)
        warn("no PTDF supplied")
        PTDF,  A = PowerSystems.buildptdf(sys.branches, sys.buses) 
    end

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args..., PTDF=PTDF)
    end     
end

function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: AbstractDCPowerModel}

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args...)
    end 
    
end

function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: Union{DCAngleLLForm, DCAngleForm}}

    anglevariables(m, system_formulation, sys)

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args...)
    end
    
end


function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: AbstractACPowerModel}

    anglevariables(m, system_formulation, sys)

    voltagevariables(m, system_formulation, sys)

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args...)
    end
    
end
