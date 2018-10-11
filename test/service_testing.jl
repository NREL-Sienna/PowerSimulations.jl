using PowerSystems
using JuMP
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  1000.0);
using PowerSimulations
const PS = PowerSimulations

simple_reserve = PowerSystems.StaticReserve("test_reserve",vcat(sys5.generators.thermal,sys5.generators.renewable[2]),60.0,[gen.tech for gen in sys5.generators.thermal])
#simple_reserve = PowerSystems.StaticReserve("test_reserve",sys5.generators.thermal,60.0,[sys5.generators.thermal[1].tech])

@test try
    Net = PS.CopperPlatePowerModel
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
    PS.constructdevice!(m, netinjection, ElectricLoad, PS.InterruptibleLoad, Net, sys5);
    PS.constructnetwork!(m, [(device=Branch, formulation=PS.PiLine)], netinjection, Net, sys5)
    PS.constructservice!(m, simple_reserve, PS.RampLimitedReserve, [(device = ThermalGen, formulation =PS.ThermalDispatch),
                                                              (device = RenewableGen, formulation = PS.RenewableCurtail)], 
                                                              sys5)
    m.obj_dict
true finally end

@test try
    Net = PS.CopperPlatePowerModel
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.StandardThermalCommitment, Net, sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
    PS.constructdevice!(m, netinjection, ElectricLoad, PS.InterruptibleLoad, Net, sys5);
    PS.constructnetwork!(m, [(device=Branch, formulation=PS.PiLine)], netinjection, Net, sys5)
    PS.constructservice!(m, simple_reserve, PS.RampLimitedReserve, [(device = ThermalGen, formulation =PS.StandardThermalCommitment),
                                                              (device = RenewableGen, formulation = PS.RenewableCurtail)], 
                                                              sys5)
    m.obj_dict
true finally end
