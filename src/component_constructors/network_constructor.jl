function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: CopperPlatePowerModel}

    copperplatebalance(m, netinjection, sys.time_periods)

end

function constructnetwork!(m::JuMP.Model, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PowerSystems.PowerSystem; args...) where {S <: AbstractFlowForm}

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

    if :solver in keys(args)
        solver = args[:solver]
    else
        @error("The optimizer is not defined ")
    end

    PM_dict = pass_to_pm(sys)

    PM_F = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, system_formulation; kwargs...)

    PM_object = PS.build_nip_model(PM_dict, PM_F, optimizer=solver);

    #= TODO: Needs to be generalized later for other branch models not covered by PM.
    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args...)
    end
    =#

    # this is a hack... do not try by yourself
    PM_object.model.ext[:PM_object] = PM_object



    return PM_object.model
end

