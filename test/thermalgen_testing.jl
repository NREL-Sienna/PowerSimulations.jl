using PowerSystems
using PowerSimulations
using JuMP
using Compat

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0)

m = JuMP.Model()
devices_netinjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys5.buses), sys5.time_periods)

create_constraints(Thermal, m, devices_netinjection, sys5, [rampconstraints])


#Test UC
m=Model()
devices_netinjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys5.buses), sys5.time_periods)
create_constraints(Thermal, m, devices_netinjection, sys5, [commitmentconstraints, rampconstraints])


true