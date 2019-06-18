function get_branch_to_pm(ix::Int64, branch::PSY.PhaseShiftingTransformer)
    PM_branch = Dict{String,Any}(
        "br_r"        => branch.r,
        "rate_a"      => branch.rate,
        "shift"       => branch.α,
        "rate_b"      => branch.rate,
        "br_x"        => branch.x,
        "rate_c"      => branch.rate,
        "g_to"        => 0.0,
        "g_fr"        => 0.0,
        "b_fr"        => branch.primaryshunt/2,
        "f_bus"       => branch.connectionpoints.from.number,
        "br_status"   => Float64(branch.available),
        "t_bus"       => branch.connectionpoints.to.number,
        "b_to"        => branch.primaryshunt/2,
        "index"       => ix,
        "angmin"      => -π/2,
        "angmax"      =>  π/2,
        "transformer" => true,
        "tap"         => branch.tap,
    )
    return PM_branch
end

function get_branch_to_pm(ix::Int64, branch::PSY.Transformer2W)
    PM_branch = Dict{String,Any}(
        "br_r"        => branch.r,
        "rate_a"      => branch.rate,
        "shift"       => 0.0,
        "rate_b"      => branch.rate,
        "br_x"        => branch.x,
        "rate_c"      => branch.rate,
        "g_to"        => 0.0,
        "g_fr"        => 0.0,
        "b_fr"        => branch.primaryshunt/2,
        "f_bus"       => branch.connectionpoints.from.number,
        "br_status"   => Float64(branch.available),
        "t_bus"       => branch.connectionpoints.to.number,
        "b_to"        => branch.primaryshunt/2,
        "index"       => ix,
        "angmin"      => -π/2,
        "angmax"      =>  π/2,
        "transformer" => true,
        "tap"         => 1.0,
    )
    return PM_branch
end

function get_branch_to_pm(ix::Int64, branch::PSY.TapTransformer)
    PM_branch = Dict{String,Any}(
        "br_r"        => branch.r,
        "rate_a"      => branch.rate,
        "shift"       => 0.0,
        "rate_b"      => branch.rate,
        "br_x"        => branch.x,
        "rate_c"      => branch.rate,
        "g_to"        => 0.0,
        "g_fr"        => 0.0,
        "b_fr"        => branch.primaryshunt/2,
        "f_bus"       => branch.connectionpoints.from.number,
        "br_status"   => Float64(branch.available),
        "t_bus"       => branch.connectionpoints.to.number,
        "b_to"        => branch.primaryshunt/2,
        "index"       => ix,
        "angmin"      => -π/2,
        "angmax"      =>  π/2,
        "transformer" => true,
        "tap"         => branch.tap
    )
    return PM_branch
end

function get_branch_to_pm(ix::Int64, branch::PSY.Line)
    PM_branch = Dict{String,Any}(
        "br_r"        => branch.r,
        "rate_a"      => branch.rate,
        "shift"       => 0.0,
        "rate_b"      => branch.rate,
        "br_x"        => branch.x,
        "rate_c"      => branch.rate,
        "g_to"        => 0.0,
        "g_fr"        => 0.0,
        "b_fr"        => branch.b.from,
        "f_bus"       => branch.connectionpoints.from.number,
        "br_status"   => Float64(branch.available),
        "t_bus"       => branch.connectionpoints.to.number,
        "b_to"        => branch.b.to,
        "index"       => ix,
        "angmin"      => branch.anglelimits.min,
        "angmax"      => branch.anglelimits.max,
        "transformer" => false,
        "tap"         => 1.0,
    )
    return PM_branch
end

function get_branch_to_pm(ix::Int64, branch::PSY.HVDCLine)
    PM_branch = Dict{String,Any}(
        "loss1"         => branch.loss.l1,
        "mp_pmax"       => branch.reactivepowerlimits_from.max,
        "model"         => 2,
        "shutdown"      => 0.0,
        "pmaxt"         => branch.activepowerlimits_to.max,
        "pmaxf"         => branch.activepowerlimits_from.max,
        "startup"       => 0.0,
        "loss0"         => branch.loss.l1,
        "pt"            => 0.0,
        "vt"            => branch.connectionpoints.to.voltage,
        "qmaxf"         => branch.reactivepowerlimits_from.max,
        "pmint"         => branch.activepowerlimits_to.min,
        "f_bus"         => branch.connectionpoints.from.number,
        "mp_pmin"       => branch.reactivepowerlimits_from.min,
        "br_status"     => Float64(branch.available),
        "t_bus"         => branch.connectionpoints.to.number,
        "index"         => ix,
        "qmint"         => branch.reactivepowerlimits_to.min,
        "qf"            => 0.0,
        "cost"          => 0.0,
        "pminf"         => branch.activepowerlimits_from.min,
        "qt"            => 0.0,
        "qminf"         => branch.reactivepowerlimits_from.min,
        "vf"            => branch.connectionpoints.from.voltage,
        "qmaxt"         => branch.reactivepowerlimits_to.max,
        "ncost"         => 0,
        "pf"            => 0.0
    )
    return PM_branch
end

function get_branches_to_pm(sys::PSY.System)

        PM_ac_branches = Dict{String,Any}()
        PM_dc_branches = Dict{String,Any}()

        for (ix, branch) in enumerate(PSY.get_components(PSY.Branch, sys))
            if isa(branch,PSY.DCBranch)
                PM_dc_branches["$(ix)"] = get_branch_to_pm(ix, branch)
            else
                PM_ac_branches["$(ix)"] = get_branch_to_pm(ix, branch)
            end
        end

    return PM_ac_branches, PM_dc_branches
end

function get_buses_to_pm(buses::PSY.FlattenedVectorsIterator{PSY.Bus})
    PM_buses = Dict{String,Any}()
    for bus in buses
        PM_bus = Dict{String,Any}(
        "zone"     => 1,
        "bus_i"    => bus.number,
        "bus_type" => bus.bustype,
        "vmax"     => bus.voltagelimits.max,
        "area"     => 1,
        "vmin"     => bus.voltagelimits.min,
        "index"    => bus.number,
        "va"       => bus.angle,
        "vm"       => bus.voltage,
        "base_kv"  => bus.basevoltage,
        "pni"      => 0.0,
        "qni"      => 0.0,
        )
        PM_buses["$(bus.number)"] = PM_bus
    end
    return PM_buses
end

function pass_to_pm(sys::PSY.System, time_periods::Int64)

    ac_lines, dc_lines = get_branches_to_pm(sys)
    buses = PSY.get_components(PSY.Bus, sys)
    PM_translation = Dict{String,Any}(
    "bus"            => get_buses_to_pm(buses),
    "branch"         => ac_lines,
    "baseMVA"        => sys.basepower,
    "per_unit"       => true,
    "storage"        => Dict{String,Any}(),
    "dcline"         => dc_lines,
    "gen"            => Dict{String,Any}(),
    "shunt"          => Dict{String,Any}(),
    "load"           => Dict{String,Any}(),
    )

    # TODO: this function adds overhead in large number of time_steps
    # We can do better later.

    PM_translation = PM.replicate(PM_translation, time_periods)

    return PM_translation

end