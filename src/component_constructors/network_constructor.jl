function constructnetwork!(m::JuMP.AbstractModel, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel}

    copperplatebalance(m, netinjection, sys.time_periods)

end

function constructnetwork!(m::JuMP.AbstractModel, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: StandardPTDFModel}

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; kwargs...)
    end

    nodalflowbalance(m, netinjection, system_formulation, sys)

end

function constructnetwork!(m::JuMP.AbstractModel, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{StandardPTDF}, sys::PSY.PowerSystem; kwargs...)
    if :PTDF in keys(args)
        PTDF = args[:PTDF]
    else
        PTDF = nothing
    end

    if !isa(PTDF,PTDFArray)
        @warn "no PTDF supplied"
        PTDF,  A = PSY.buildptdf(sys.branches, sys.buses)
    end

    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args..., PTDF=PTDF)
    end

    nodalflowbalance(m, netinjection, system_formulation, sys)

end

function constructnetwork!(m::JuMP.AbstractModel, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: PM.AbstractActivePowerFormulation}

    #= TODO: Needs to be generalized later for other branch models not covered by PM.
    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; kwargs...)
    end
    =#

    nodalflowbalance(m, netinjection, system_formulation, sys)

    PM_F = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, system_formulation; kwargs...)

    PM_object = PSI.build_nip_expr_model(m.ext[:PM_object], PM_F, jump_model=m);

    m = PM_object.model

end

function constructnetwork!(m::JuMP.AbstractModel, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: PM.AbstractPowerFormulation}

    #= TODO: Needs to be generalized later for other branch models not covered by PM.
    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; kwargs...)
    end
    =#

    nodalflowbalance(m, netinjection, system_formulation, sys)

    PM_F = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, system_formulation; kwargs...)

    PM_object = PSI.build_nip_expr_model(m.ext[:PM_object], PM_F, jump_model=m);

    m.ext[:PM_object] = PM_object

end
