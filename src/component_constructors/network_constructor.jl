function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: CopperPlatePowerModel}

    copperplatebalance(m, netinjection, sys.time_periods)

end

function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: AbstractFlowForm}

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args...)
    end

    nodalflowbalance(m, netinjection, system_formulation, sys)

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

    nodalflowbalance(m, netinjection, system_formulation, sys)

end

function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: AbstractDCPowerModel}

    #= TODO: Needs to be generalized later for other branch models not covered by PM.
    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args...)
    end
    =#

    nodalflowbalance(m, netinjection, system_formulation, sys)

    PM_F = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, system_formulation; kwargs...)

    PM_object = PS.build_nip_model(PM_dict, PM_F, jump_model=m);

    m = PM_object.model

end

function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: AbstractACPowerModel}

    #= TODO: Needs to be generalized later for other branch models not covered by PM.
    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args...)
    end
    =#

    nodalflowbalance(m, netinjection, system_formulation, sys)

    PM_F = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, system_formulation; kwargs...)

    PM_object = PS.build_nip_model(PM_dict, PM_F, jump_model=m);

    m.ext[:PM_object] = PM_object

end
