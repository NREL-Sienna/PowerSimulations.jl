function constructdevice!(m::JuMP.AbstractModel, category::Type{B}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {B <: PSY.Branch, D <: AbstractBranchForm, S <: StandardPTDFModel}

    flow_variables(m, system_formulation, sys.branches, sys.time_periods)

    thermalflowlimits(m, system_formulation, sys.branches, sys.time_periods)

end

function constructdevice!(m::JuMP.AbstractModel, category::Type{B}, category_formulation::Type{PiLine}, system_formulation::Type{StandardPTDFModel}, sys::PSY.PowerSystem; kwargs...) where {B <: PSY.Branch}

    PTDF = [a.second for a in args if a.first == :PTDF][1]

    ac_branches_set = [b.name for b in sys.branches if isa(b,category)]

    isempty(PTDF) ? @error("NO PTDF matrix has been provided") : (size(PTDF.axes[1])[1] != length(ac_branches_set) ? @error("PTDF size is inconsistent") : true)

    flow_variables(m, system_formulation, sys.branches, sys.time_periods)

    thermalflowlimits(m, system_formulation, sys.branches, sys.time_periods)

    dc_networkflow(m, netinjection, PTDF)

end
