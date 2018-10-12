using PowerSystems
using JuMP
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  1000.0);
using PowerSimulations
const PS = PowerSimulations

@test try
    Net = PS.CopperPlatePowerModel
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
    PS.constructdevice!(m, netinjection, ElectricLoad, PS.InterruptibleLoad, Net, sys5);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5)
    m.obj_dict
true finally end

# Flow Models
@test try
    Net = PS.StandardNetFlow
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
    PS.constructdevice!(m, netinjection, ElectricLoad, PS.InterruptibleLoad, Net, sys5);
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5)
    m.obj_dict
true finally end

@test try
    Net = PS.StandardNetFlowLL
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
    PS.constructdevice!(m, netinjection, ElectricLoad, PS.InterruptibleLoad, Net, sys5);
    #Branch models are not implemented yet. They don't reflect losses.
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5)
    m.obj_dict
true finally end

# Flow Models
@test try
    Net = PS.StandardPTDF
    m = Model();
    ptdf,  A = PowerSystems.buildptdf(sys5.branches, sys5.buses)
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
    PS.constructdevice!(m, netinjection, ElectricLoad, PS.InterruptibleLoad, Net, sys5);
    #Branch models are not implemented yet. They don't reflect losses.
    PS.constructnetwork!(m, [(device=Line, formulation=PS.PiLine)], netinjection, Net, sys5, PTDF = ptdf)
    m.obj_dict
true finally end