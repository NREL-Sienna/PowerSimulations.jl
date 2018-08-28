using PowerSystems
using PowerSimulations
using JuMP
using Compat

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  1000.0)

m = JuMP.Model()
devices_netinjection =  PowerSimulations.JumpAffineExpressionArray(length(sys5.buses), sys5.time_periods)

PowerSimulations.constructdevice!(RenewableGen, CopperPlatePowerModel, m, devices_netinjection, sys5, [curtailconstraints])

true