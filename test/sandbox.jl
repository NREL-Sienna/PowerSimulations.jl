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

generators_th = [  ThermalDispatch("Alta", true, nodes5[1],
                    TechThermal(40.0, @NT(min=0.0, max=40.0), 10.0, @NT(min = -30.0, max = 30.0), @NT(up = 10.0, down = 10.0), @NT(up = 1.0, down = 1.0)),
                    EconThermal(40.0, 14.0, 0.0, 0.0, 0.0, nothing)
                ),
                ThermalDispatch("Park City", true, nodes5[1],
                    TechThermal(170.0, @NT(min=0.0, max=170.0), 20.0, @NT(min =-127.5, max=127.5), @NT(up = 10.0, down = 10.0), @NT(up = 1.0, down = 1.0)),
                    EconThermal(170.0, 15.0, 0.0, 0.0, 0.0, nothing)
                ),
                ThermalDispatch("Solitude", true, nodes5[3],
                    TechThermal(520.0, @NT(min=0.0, max=520.0), 100.0, @NT(min =-390.0, max=390.0), @NT(up = 10.0, down = 10.0), @NT(up = 1.0, down = 1.0)),
                    EconThermal(520.0, 30.0, 0.0, 0.0, 0.0, nothing)
                ),
                ThermalDispatch("Sundance", true, nodes5[4],
                    TechThermal(200.0, @NT(min=0.0, max=200.0), 40.0, @NT(min =-150.0, max=150.0), @NT(up = 10.0, down = 10.0), @NT(up = 1.0, down = 1.0)),
                    EconThermal(200.0, 40.0, 0.0, 0.0, 0.0, nothing)
                ),
                ThermalDispatch("Brighton", true, nodes5[5],
                    TechThermal(600.0, @NT(min=0.0, max=600.0), 150.0, @NT(min =-450.0, max=450.0), @NT(up = 10.0, down = 10.0), @NT(up = 1.0, down = 1.0)),
                    EconThermal(600.0, 10.0, 0.0, 0.0, 0.0, nothing)
                )];

generators_re = [
                RenewableFix("SolarBusC", true, nodes5[3],
                    60.0,
                    TimeSeries.TimeArray(DayAhead,solar_ts_DA)
                ),
                RenewableCurtailment("WindBusA", true, nodes5[5],
                    120.0,
                    EconRenewable(22.0, nothing),
                    TimeSeries.TimeArray(DayAhead,wind_ts_DA)
                )
            ];
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
pth = PowerSimulations.GenerationVariables(m, sys5b.generators.thermal, sys5b.timesteps)
on_th, start_th, stopth = PowerSimulations.CommitmentVariables(m, sys5b.generators.thermal, sys5b.timesteps)
pre = PowerSimulations.GenerationVariables(m, sys5b.generators.renewable, sys5b.timesteps)
Pin, Pout = PowerSimulations.GenerationVariables(m, sys5b.storage, sys5b.timesteps)
Es = PowerSimulations.StorageVariables(m, sys5b.storage, sys5b.timesteps);
phg = PowerSimulations.GenerationVariables(m, generators_hg, sys5b.timesteps)
fl = PowerSimulations.BranchFlowVariables(m, sys5b.network.branches, sys5b.timesteps)
pcl = PowerSimulations.LoadVariables(m, sys5b.loads, sys5b.timesteps)

#Injection Array
Nets = PowerSimulations.InjectionExpressions(m, sys5b, var_th = pth, var_re=pre, var_cl = pcl, var_in = Pin, var_out = Pout)
#CopperPlate Network test
PowerSimulations.CopperPlateNetwork(m, Nets, sys5b.timesteps)

#Constraint Generation
#Power Limit Constraints
PowerSimulations.PowerConstraints(m, pre, [generators_re[2]], sys5b.timesteps)

#Controllable Load Constraints
PowerSimulations.PowerConstraints(m, pcl, [sys5.loads[4]], sys5b.timesteps)

#Thermal Generation Constraints
PowerSimulations.PowerConstraints(m, pth, generators_th, sys5b.timesteps)
PowerSimulations.RampConstraints(m,pth ,generators_th, sys5b.timesteps)


#Storage Constraints
PowerSimulations.PowerConstraints(m, Pin, Pout, sys5b.storage, sys5b.timesteps)
PowerSimulations.EnergyConstraint(m , Es, sys5b.storage, sys5b.timesteps)
PowerSimulations.EnergyBookKeeping(m ,Pin ,Pout, Es, sys5b.storage, sys5b.timesteps)


#Hydro Generation Constraints
PowerSimulations.PowerConstraints(m, phg, [generators_hg[2]], sys5b.timesteps)


#=


PowerSimulations.CommitmentStatus_th(m ,on_th ,start_th, stopth, generators_th, sys5b.timesteps)
PowerSimulations.MinimumUpTime_th(m ,on_th ,start_th ,generators_th, sys5b.timesteps)
PowerSimulations.MinimumDownTime_th(m ,on_th ,stopth ,generators_th, sys5b.timesteps)
=#

#Cost Functions


true
