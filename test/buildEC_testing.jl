using PowerSystems
using PowerSimulations
using JuMP
using Clp

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))

sys5b = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 230.0, 1000.0)

m=JuMP.Model()
DevicesNetInjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys5b.buses), sys5b.time_periods)

#Thermal Generator Models
pth, IArray = PowerSimulations.generationvariables(m, DevicesNetInjection,  sys5b.generators.thermal, sys5b.time_periods);
m = PowerSimulations.powerconstraints(m, pth, sys5b.generators.thermal, sys5b.time_periods)
pre_set = [d for d in sys5b.generators.renewable if !isa(d, RenewableFix)]
pre, IArray = PowerSimulations.generationvariables(m, DevicesNetInjection, pre_set, sys5b.time_periods)
m = PowerSimulations.powerconstraints(m, pre, pre_set, sys5b.time_periods)
test_cl = [d for d in sys5b.loads if !isa(d, PowerSystems.StaticLoad)] # Filter StaticLoads Out
pcl, IArray = PowerSimulations.loadvariables(m, DevicesNetInjection, test_cl, sys5b.time_periods);
m = PowerSimulations.powerconstraints(m, pcl, test_cl, sys5b.time_periods)

#Injection Array
TsNets = PowerSimulations.tsinjectionbalance(sys5b)
#CopperPlate Network test
m = PowerSimulations.copperplatebalance(m, IArray, TsNets, sys5b.time_periods);

#Cost Components
tl = PowerSimulations.variablecost(m, pcl, test_cl);
tre = PowerSimulations.variablecost(m, pre, pre_set)
tth = PowerSimulations.variablecost(m, pth, sys5b.generators.thermal);

#objective
@objective(m, Min, tl+tre+tth);

m = PowerSimulations.solvepsmodel(m);