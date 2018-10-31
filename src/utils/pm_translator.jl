function get_branch_to_pm(ix::Int64, branch::PowerSystems.Transformer2W)
    PM_branch = Dict{String,Any}(
        "br_r"        => branch.r,
        "rate_a"      => branch.rate,
        "shift"       => 0.0,
        "rate_b"      => branch.rate,
        "br_x"        => branch.r,
        "rate_c"      => branch.rate,
        "g_to"        => 0.0,
        "g_fr"        => 0.0,
        "b_fr"        => branch.primaryshunt/2,
        "f_bus"       => branch.connectionpoints.from.number,
        "br_status"   => Float64(branch.available),
        "t_bus"       => branch.connectionpoints.to.number,
        "b_to"        => branch.primaryshunt/2,
        "index"       => ix,
        "angmin"      => -1.50,
        "angmax"      =>  1.50,
        "transformer" => true,
        "tap"         => 1.0,
    )
    return PM_branch
end

function get_branch_to_pm(ix::Int64, branch::PowerSystems.TapTransformer)
    PM_branch = Dict{String,Any}(
        "br_r"        => branch.r,
        "rate_a"      => branch.rate,
        "shift"       => 0.0,
        "rate_b"      => branch.rate,
        "br_x"        => branch.r,
        "rate_c"      => branch.rate,
        "g_to"        => 0.0,
        "g_fr"        => 0.0,
        "b_fr"        => branch.primaryshunt/2,
        "f_bus"       => branch.connectionpoints.from.number,
        "br_status"   => Float64(branch.available),
        "t_bus"       => branch.connectionpoints.to.number,
        "b_to"        => branch.primaryshunt/2,
        "index"       => ix,
        "angmin"      => -1.50,
        "angmax"      =>  1.50,
        "transformer" => true,
        "tap"         => branch.tap
    )
    return PM_branch
end

function get_branch_to_pm(ix::Int64, branch::PowerSystems.Line)
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
    return PM_branch
end


function get_branches_to_pm(branches::Array{T}) where {T <: PowerSystems.Branch}
        PM_branches = Dict{String,Any}()

        for (ix, branch) in enumerate(branches)
            PM_branches["$(ix)"] = get_branch_to_pm(ix, branch)
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
        "pni"      => 0.0,
        "qni"      => 0.0,
        )
        PM_buses["$(bus.number)"] = PM_bus
    end
    PM_buses["$(buses[1].number)"]["bus_type"] = 3
    return PM_buses
end

#=
function expression_to_pm_active(PM_dict::Dict{String,Any}, netinjection::BalanceNamedTuple, sys::PowerSystems.PowerSystem)

    for bus in sys.buses, time in 1:sys.time_periods

        PM_dict["nw"]["$(time)"]["bus"]["$(bus.number)"]["pni"] = netinjection.var_active[bus.number,time]

    end

end

function expression_to_pm_reactive(PM_dict::Dict{String,Any}, netinjection::BalanceNamedTuple, sys::PowerSystems.PowerSystem)

    for bus in sys.buses, time in 1:sys.time_periods

        PM_dict["nw"]["$(time)"]["bus"]["$(bus.number)"]["qni"] = netinjection.var_reactive[bus.number,time]

    end

end
=#

function pass_to_pm(sys::PowerSystems.PowerSystem, netinjection::BalanceNamedTuple)

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



