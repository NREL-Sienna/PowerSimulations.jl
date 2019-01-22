using PowerSystems
using JuMP
using Ipopt
using PowerSimulations
const PS = PowerSimulations

ipopt_optimizer = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)

base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus_pu.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  100.0);


@test try
    @info "testing copper plate"
    Net = PSI.CopperPlatePowerModel
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

# Flow Models
@test try
    @info "testing net flow"
    Net = PSI.StandardNetFlow
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

# Flow Models
@test try
    @info "testing PTDF 5-bus"
    Net = PSI.StandardPTDFModel
    m = Model(ipopt_optimizer);
    ptdf,  A = PSY.buildptdf(sys5.branches, sys5.buses)
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5, PTDF = ptdf)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

@test try
    @info "testing AngleDC-OPF 5-bus"
    Net = PSI.DCAngleForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

@test try
    @info "testing ACP-OPF 5-bus"
    Net = PSI.StandardAC
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
true finally end

@test try
    @info "testing ACP- QCWForm 5-bus"
    Net = PM.QCWRForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
true finally end



include(joinpath(base_dir,"data/data_14bus_pu.jl"))
sys14 = PowerSystem(nodes14, generators14, loads14, branches14, nothing,  100.0);


@test try
    @info "testing copper plate 14-bus"
    Net = PSI.CopperPlatePowerModel
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

# Flow Models
@test try
    @info "testing net 14-bus"
    Net = PSI.StandardNetFlow
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

# Flow Models
@test_skip try
    @info "testing PTDF 14-bus"
    Net = PSI.StandardPTDFModel
    m = Model(ipopt_optimizer);
    ptdf,  A = PSY.buildptdf(sys14.branches, sys14.buses)
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14, PTDF = ptdf)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

@test try
    @info "testing AngleDC-OPF 14-bus"
    Net = PSI.DCAngleForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

@test try
    @info "testing ACP-OPF 14-bus"
    Net = PSI.StandardAC
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
true finally end

@test try
    @info "testing ACP-QCWForm 14-bus"
    Net = PM.QCWRForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
true finally end
