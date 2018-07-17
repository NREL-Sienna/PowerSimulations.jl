using PowerSystems
using PowerSimulations
using JuMP

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 230.0, 1000.0)

m = JuMP.Model()
DevicesNetInjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys5.buses), sys5.time_periods)

pre_set = [d for d in sys5.generators.renewable if !isa(d, RenewableFix)]
pre, IArray = PowerSimulations.generationvariables(m, DevicesNetInjection, pre_set, sys5.time_periods)
m = PowerSimulations.powerconstraints(m, pre, pre_set, sys5.time_periods)

true