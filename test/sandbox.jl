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
tp = 5; 

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

#Variable Creation Testing            
pth = PowerSimulations.GenerationVariables(m, generators_th, tp)
on_th, start_th, stopth = PowerSimulations.CommitmentVariables(m, generators_th, tp)
pre = PowerSimulations.GenerationVariables(m, generators_re, tp)
Pin, Pout = PowerSimulations.GenerationVariables(m, [battery], tp)
Es = PowerSimulations.StorageVariables(m, [battery], tp);
fl = PowerSimulations.BranchFlowVariables(m, sys5.network.branches, tp)
pcl = PowerSimulations.LoadVariables(m, sys5.loads, tp)

#Device Constraint creation testing 
PowerSimulations.PowerConstraints(m, pth, generators_th, tp)
PowerSimulations.PowerConstraints(m, pre, [generators_re[2]], tp)
PowerSimulations.PowerConstraints(m, pcl, [sys5.loads[4]], tp)
PowerSimulations.PowerConstraints(m, Pin, Pout, [battery], tp)
PowerSimulations.RampingConstraints_th(m,pth ,generators_th, tp)
PowerSimulations.EnergyLimitConstraint(m , Es, [battery], tp)
PowerSimulations.EnergyBalanceConstraint(m ,Pin ,Pout, Es, [battery], tp)
PowerSimulations.CommitmentStatus_th(m ,on_th ,start_th, stopth, generators_th, tp)
PowerSimulations.MinimumUpTime_th(m ,on_th ,start_th ,generators_th, tp)
PowerSimulations.MinimumDownTime_th(m ,on_th ,stopth ,generators_th, tp)