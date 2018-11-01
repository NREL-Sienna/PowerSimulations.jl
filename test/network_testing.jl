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
    @info "testing copper plate 5-bus"
    Net = PS.CopperPlatePowerModel
    m = Model(ipopt_optimizer);
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

# Flow Models
@test try
    @info "testing net 5-bus"
    Net = PS.StandardNetFlow
    m = Model(ipopt_optimizer);
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

# Flow Models
@test try
    @info "testing PTDF 5-bus"
    Net = PS.StandardPTDF
    m = Model(ipopt_optimizer);
    ptdf,  A = PowerSystems.buildptdf(sys5.branches, sys5.buses)
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5, PTDF = ptdf)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

@test try
    @info "testing AngleDC-OPF 5-bus"
    Net = PS.DCAngleForm
    m = Model(ipopt_optimizer);
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

@test try
    @info "testing ACP-OPF 5-bus"
    Net = PS.StandardAC
    m = Model(ipopt_optimizer);
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
true finally end


include(joinpath(base_dir,"data/data_14bus_pu.jl"))
sys14 = PowerSystem(nodes14, generators14, loads14, branches14, nothing,  100.0);


@test try
    @info "testing copper plate 14-bus"
    Net = PS.CopperPlatePowerModel
    m = Model(ipopt_optimizer);
    netinjection = PS.instantiate_network(Net, sys14);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys14);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys14)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

# Flow Models
@test try
    @info "testing net 14-bus"
    Net = PS.StandardNetFlow
    m = Model(ipopt_optimizer);
    netinjection = PS.instantiate_network(Net, sys14);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys14);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys14)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

# Flow Models
@test try
    @info "testing PTDF 14-bus"
    Net = PS.StandardPTDF
    m = Model(ipopt_optimizer);
    ptdf,  A = PowerSystems.buildptdf(sys14.branches, sys14.buses)
    netinjection = PS.instantiate_network(Net, sys14);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys14);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys14, PTDF = ptdf)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

@test try
    @info "testing AngleDC-OPF 14-bus"
    Net = PS.DCAngleForm
    m = Model(ipopt_optimizer);
    netinjection = PS.instantiate_network(Net, sys14);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys14);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys14)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

@test try
    @info "testing ACP-OPF 14-bus"
    Net = PS.StandardAC
    m = Model(ipopt_optimizer);
    netinjection = PS.instantiate_network(Net, sys14);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys14);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys14)
    @objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
true finally end