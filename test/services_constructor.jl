#=
using PowerSystems
using JuMP
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))
sys5 = PSY.System(nodes5, generators5, loads5_DA, branches5, nothing,  100.0);
using PowerSimulations
const PS = PowerSimulations

simple_reserve = PSY.StaticReserve("test_reserve",vcat(sys5.generators.thermal,sys5.generators.renewable[2]),60.0,[gen.tech for gen in sys5.generators.thermal])
#simple_reserve = PSY.StaticReserve("test_reserve",sys5.generators.thermal,60.0,[sys5.generators.thermal[1].tech])

@test try
    Net = PSI.CopperPlatePowerModel
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.construct_device!(m, netinjection, RenewableGen, PSI.RenewableCurtail, Net, sys5);
    PSI.construct_device!(m, netinjection, ElectricLoad, PSI.InterruptibleLoad, Net, sys5);
    PSI.construct_network!(m, [(device=Branch, formulation=PSI.PiLine)], netinjection, Net, sys5)
    PSI.construct_service!(m, simple_reserve, PSI.RampLimitedReserve, [(device = ThermalGen, formulation =PSI.ThermalDispatch),
                                                              (device = RenewableGen, formulation = PSI.RenewableCurtail)],
                                                              sys5)
    m.obj_dict
true finally end

@test try
    Net = PSI.CopperPlatePowerModel
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalUnitCommitment , Net, sys5);
    PSI.construct_device!(m, netinjection, RenewableGen, PSI.RenewableCurtail, Net, sys5);
    PSI.construct_device!(m, netinjection, ElectricLoad, PSI.InterruptibleLoad, Net, sys5);
    PSI.construct_network!(m, [(device=Branch, formulation=PSI.PiLine)], netinjection, Net, sys5)
    PSI.construct_service!(m, simple_reserve, PSI.RampLimitedReserve, [(device = ThermalGen, formulation =PSI.ThermalUnitCommitment ),
                                                              (device = RenewableGen, formulation = PSI.RenewableCurtail)],
                                                              sys5)
    m.obj_dict
true finally end
=#