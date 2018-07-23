struct CopperPlate end
struct NodalBalance end

function constructnetwork(category::Type{CopperPlate}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem) where T <: PowerExpressionArray

    TsNets = PowerSimulations.timeseries_netinjection(sys);

    m = PowerSimulations.copperplatebalance(m, devices_netinjection, TsNets, sys.time_periods);

    return m

end

function constructnetwork(category::Type{NodalBalance}, m::JuMP.Model, devices_netinjection::T, sys::PowerSystems.PowerSystem) where T <: PowerExpressionArray

    TsNets = PowerSimulations.timeseries_netinjection(sys);

    #assume the devices_netinjection already has the branch_flow variables. nodalflow balances needs to be updated.

    m = PowerSimulations.nodalflowbalance(m, devices_netinjection, TsNets, sys.time_periods);

    return m

end
