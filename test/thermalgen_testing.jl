using PowerSystems
using JuMP
using Compat

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 230.0, 1000.0)

m = JuMP.Model()
DevicesNetInjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys5.buses), sys5.time_periods)

#Test ED
pth, IArray = PowerSimulations.generationvariables(m, DevicesNetInjection,  sys5.generators.thermal, sys5.time_periods);
PowerSimulations.powerconstraints(m, pth, sys5.generators.thermal, sys5.time_periods)
gen_ramp = [d for d in sys5.generators.thermal if !isa(d.tech.ramplimits,Nothing)]
!isempty(gen_ramp) ? PowerSimulations.rampconstraints(m, pth, gen_ramp, sys5.time_periods) : true


#Test UC
m=Model()
pth, IArray = PowerSimulations.generationvariables(m, DevicesNetInjection,  sys5.generators.thermal, sys5.time_periods);
on_th, start_th, stop_th = PowerSimulations.commitmentvariables(m, sys5.generators.thermal, sys5.time_periods)
PowerSimulations.powerconstraints(m, pth, on_th, sys5.generators.thermal, sys5.time_periods)
gen_ramp = [d for d in sys5.generators.thermal if !isa(d.tech.ramplimits,Nothing)]
!isempty(gen_ramp) ? PowerSimulations.rampConstraints(m, pth, on_th, sys5.generators.thermal, sys5.time_periods) : true
PowerSimulations.commitmentconstraints(m, on_th, start_th, stop_th, sys5.generators.thermal, sys5.time_periods)
gen_time = [d for d in sys5.generators.thermal if !isa(d.tech.timelimits,Nothing)]
!isempty(gen_time) ? PowerSimulations.timeconstraints(m, on_th, start_th, stop_th, gen_time, sys5.time_periods) : true

true