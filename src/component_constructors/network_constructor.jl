function constructnetwork!(ps_m::CanonicalModel, system_formulation::Type{CopperPlatePowerModel}, sys::PSY.PowerSystem; kwargs...)

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods
    bus_count = length(sys.buses)

    copper_plate(ps_m, "var_active", bus_count, time_range)


end

function constructnetwork!(ps_m::CanonicalModel, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, system_formulation::Type{StandardPTDFModel}, sys::PSY.PowerSystem; kwargs...)
#=
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
=#

end

function constructnetwork!(ps_m::CanonicalModel, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: PM.AbstractPowerFormulation}

    #=

 
    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; kwargs...)
    end
 

    nodalflowbalance(m, netinjection, system_formulation, sys)

    PM_F = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, system_formulation; kwargs...)

    PM_object = PSI.build_nip_expr_model(m.ext[:PM_object], PM_F, jump_model=m);

    m = PM_object.model

    =#
    
end