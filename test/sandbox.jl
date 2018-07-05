using PowerSystems
using JuMP

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))

battery = GenericBattery(name = "Bat",
                status = true,
                energy = 10.0,
                realpower = 10.0,
                capacity = @NT(min = 0.0, max = 10.0,),
                inputrealpowerlimit = 10.0,
                outputrealpowerlimit = 10.0,
                efficiency = @NT(in = 0.90, out = 0.80),
                );
sys5b = PowerSystem(nodes5, generators5, loads5_DA, branches5, [battery], 230.0, 1000.0)
;

m = Model()

generators_hg = [
                HydroFix("HydroFix",true,nodes5[2],
                    TechHydro(60.0, 15.0, @NT(min = 0.0, max = 60.0), nothing, nothing, nothing, nothing),
                    TimeSeries.TimeArray(DayAhead,solar_ts_DA)
                ),
                HydroCurtailment("HydroCurtailment",true,nodes5[3],
                    TechHydro(60.0, 10.0, @NT(min = 0.0, max = 60.0), nothing, nothing, @NT(up = 10.0, down = 10.0), nothing),
                    1000.0,TimeSeries.TimeArray(DayAhead,wind_ts_DA) )
]

#Variable Creation Testing


phg = PowerSimulations.generationvariables(m, generators_hg, sys5b.time_periods)
pcl = PowerSimulations.LoadVariables(m, sys5b.loads, sys5b.time_periods)



#Constraint Generation


#Controllable Load Constraints
PowerSimulations.powerconstraints(m, pcl, [sys5.loads[4]], sys5b.time_periods)

#Storage Constraints



#Hydro Generation Constraints
PowerSimulations.powerconstraints(m, phg, [generators_hg[2]], sys5b.time_periods)


#=


PowerSimulations.CommitmentStatus_th(m ,on_th ,start_th, stopth, generators_th, sys5b.time_periods)
PowerSimulations.MinimumUpTime_th(m ,on_th ,start_th ,generators_th, sys5b.time_periods)
PowerSimulations.MinimumDownTime_th(m ,on_th ,stopth ,generators_th, sys5b.time_periods)
=#

#Cost Functions


true
