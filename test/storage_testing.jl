using PowerSystems
using JuMP

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))

battery = [GenericBattery(name = "Bat",
                status = true,
                energy = 10.0,
                realpower = 10.0,
                capacity = @NT(min = 0.0, max = 10.0,),
                inputrealpowerlimit = 10.0,
                outputrealpowerlimit = 10.0,
                efficiency = @NT(in = 0.90, out = 0.80),
                )];
sys5b = PowerSystem(nodes5, generators5, loads5_DA, branches5, battery, 230.0, 1000.0)
;

m = Model()

Pin, Pout = PowerSimulations.generationvariables(m, sys5b.storage, sys5b.time_periods)
Es = PowerSimulations.storagevariables(m, sys5b.storage, sys5b.time_periods);
PowerSimulations.powerconstraints(m, Pin, Pout, sys5b.storage, sys5b.time_periods)
PowerSimulations.energyconstraint(m , Es, sys5b.storage, sys5b.time_periods)
PowerSimulations.energybookkeeping(m ,Pin ,Pout, Es, sys5b.storage, sys5b.time_periods)

true