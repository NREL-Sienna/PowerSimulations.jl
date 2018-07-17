using PowerSystems
using PowerSimulations
using JuMP

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))

battery = [GenericBattery(name = "Bat",
                status = true,
                bus = nodes5[1],
                realpower = 10.0,
                energy = 5.0,
                capacity = @NT(min = 0.0, max = 0.0),
                inputrealpowerlimits = @NT(min = 0.0, max = 50.0),
                outputrealpowerlimits = @NT(min = 0.0, max = 50.0),
                efficiency = @NT(in = 0.90, out = 0.80),
                )];

generators_hg = [
    HydroFix("HydroFix",true,nodes5[2],
        TechHydro(60.0, 15.0, @NT(min = 0.0, max = 60.0), nothing, nothing, nothing, nothing),
        TimeSeries.TimeArray(DayAhead,solar_ts_DA)
    ),
    HydroCurtailment("HydroCurtailment",true,nodes5[3],
        TechHydro(60.0, 10.0, @NT(min = 0.0, max = 60.0), nothing, nothing, @NT(up = 10.0, down = 10.0), nothing),
        1000.0,TimeSeries.TimeArray(DayAhead,wind_ts_DA) )
]

sys5b = PowerSystem(nodes5, append!(generators5, generators_hg), loads5_DA, branches5, battery, 230.0, 1000.0)

m = Model()
DevicesNetInjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys5b.buses), sys5b.time_periods)

Pin, Pout, IArray = PowerSimulations.powerstoragevariables(m, DevicesNetInjection, sys5b.storage, sys5b.time_periods)
Es = PowerSimulations.energystoragevariables(m, sys5b.storage, sys5b.time_periods);
PowerSimulations.powerconstraints(m, Pin, Pout, sys5b.storage, sys5b.time_periods)
PowerSimulations.energyconstraints(m , Es, sys5b.storage, sys5b.time_periods)
PowerSimulations.energybookkeeping(m ,Pin ,Pout, Es, sys5b.storage, sys5b.time_periods)

true