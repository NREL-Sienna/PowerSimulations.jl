using PowerSystems
using PowerSimulations
using JuMP

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus.jl"))
include(joinpath(base_dir,"data/data_5bus.jl"))

sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  1000.0)

m = JuMP.Model()
devices_netinjection =  PowerSimulations.JumpAffineExpressionArray(length(sys5.buses), sys5.time_periods)

PowerSimulations.constructdevice!(RenewableGen, CopperPlatePowerModel, m, devices_netinjection, sys5, [curtailconstraints])

true