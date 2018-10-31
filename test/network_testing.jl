using PowerSystems
using JuMP
using Ipopt
ipopt_optimizer = with_optimizer(Ipopt.Optimizer)

base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  100.0);
using PowerSimulations
const PS = PowerSimulations

@test try
    @info "testing copper plate"
    Net = PS.CopperPlatePowerModel
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
    PS.constructdevice!(m, netinjection, ElectricLoad, PS.InterruptibleLoad, Net, sys5);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5)
true finally end

# Flow Models
@test try
    @info "testing net flow"
    Net = PS.StandardNetFlow
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
    PS.constructdevice!(m, netinjection, ElectricLoad, PS.InterruptibleLoad, Net, sys5);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5)
true finally end

# Flow Models
@test try
    @info "testing net flow with lost load"
    Net = PS.StandardPTDF
    m = Model();
    ptdf,  A = PowerSystems.buildptdf(sys5.branches, sys5.buses)
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    #PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
    #PS.constructdevice!(m, netinjection, ElectricLoad, PS.InterruptibleLoad, Net, sys5);
    #Branch models are not implemented yet. They don't reflect losses.
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5, PTDF = ptdf)
true finally end

@test try
    @info "testing PTDF"
    Net = PS.StandardPTDF
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    m = PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5; solver = ipopt_optimizer)
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.nodalflowbalance(m, netinjection,  Net, sys5)
    @objective(m, Min, m.obj_dict[:objective_function])
true finally end