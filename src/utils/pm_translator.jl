function get_branches_to_pm(lines::Array{PowerSystems.Line})
        PM_branches = Dict{String,Any}()
        for (ix, branch) in enumerate(lines)
            PM_branch = Dict{String,Any}(
            "br_r"        => branch.r,
            "rate_a"      => branch.rate.from_to,
            "shift"       => 0.0,
            "rate_b"      => branch.rate.from_to,
            "br_x"        => branch.r,
            "rate_c"      => branch.rate.from_to,
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
            PM_branches["$(ix)"] = PM_branch
        end
    return PM_branches
end

function get_buses_to_pm(buses::Array{PowerSystems.Bus})
    PM_buses = Dict{String,Any}()
    for bus in buses
        PM_bus = Dict{String,Any}(
        "zone"     => 1,
        "bus_i"    => bus.number,
        "bus_type" => 2,
        "vmax"     => bus.voltagelimits.max,
        "area"     => 1,
        "vmin"     => bus.voltagelimits.min,
        "index"    => bus.number,
        "va"       => bus.angle,
        "vm"       => bus.voltage,
        "base_kv"  => bus.basevoltage,
        )
        PM_buses["$(bus.number)"] = PM_bus
    end
    PM_buses["$(buses[1].number)"]["bus_type"] = 3
    return PM_buses
end

function pass_to_pm(sys::PowerSystems.PowerSystem)

    PM_translation = Dict{String,Any}(
    "bus" => get_buses_to_pm(sys.buses),
    "branch" => get_branches_to_pm(sys.branches),
    "baseMVA" => sys.basepower,
    "per_unit" => true,
    "dcline"         => Dict{String,Any}(),
    "gen"            => Dict{String,Any}(),
    "shunt"          => Dict{String,Any}(),
    "load"           => Dict{String,Any}(),
    )

    # TODO: this function adds overhead in large number of time_steps
    # We can do better later.
    PM_translation = IM.replicate(PM_translation,sys.time_periods)

    return PM_translation
end