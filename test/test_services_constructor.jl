branches = Dict{Symbol, PSI.DeviceModel}()
services = Dict{Symbol, PSI.ServiceModel}()
ED_devices = Dict{Symbol, DeviceModel}(:Generators => PSI.DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited),
                                        :Loads =>  PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
UC_devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalStandardUnitCommitment),
                                        :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
## Energy + UP-reserve Test
@testset "Solving UC with CopperPlate testing upward ramping reserve implementation" begin
    node = Bus(1,"nodeA", "PV", 0, 1.0, (min = 0.9, max=1.05), 230)
    load = PowerLoad("Bus1", true, node,nothing, 0.4, 0.9861, 1.0, 2.0)
    gens = [ThermalStandard("Alta", true, node,0.52, 0.010,
            TechThermal(0.5,PSY.PrimeMovers(6),PSY.ThermalFuels(6), 
                        (min = 0.22, max = 0.55), nothing, 
                        nothing, nothing),
            ThreePartCost([ (589.99, 0.220),(884.99, 0.33)
                ,(1210.04, 0.44),(1543.44, 0.55)],532.44, 5665.23, 0.0)
            ),
            ThermalStandard("Park City", true, node,0.62,0.20, 
                TechThermal(2.2125,PSY.PrimeMovers(6),PSY.ThermalFuels(6), 
                        (min = 0.62, max = 1.55), nothing, 
                        (up = 0.01, down= 0.01), nothing),
                ThreePartCost([   (1264.80, 0.62),(1897.20, 0.93),
                (2594.4787, 1.24),(3433.04, 1.55)   ], 235.397, 5665.23, 0.0)
            )];
    up_reserve = PSY.StaticReserve("up_reserve",gens,1.0,0.5)
    DA = collect(DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):
                        Hour(1):
                        DateTime("1/1/2024  1:00:00", "d/m/y  H:M:S"))
    enregy_load = [1.6,1.5];
    reserve_load = [1.0,1.0];
    load_forecast  = Deterministic("maxactivepower", TimeArray(DA, enregy_load))
    reserve_forecast = Deterministic("requirement", TimeArray(DA, reserve_load))
    sys = PSY.System(100.0)
    add_component!(sys, node)
    add_component!(sys, load)
    add_component!(sys, gens[1])
    add_component!(sys, gens[2])
    add_component!(sys, up_reserve)
    add_forecast!(sys, load, load_forecast)
    add_forecast!(sys, up_reserve, reserve_forecast)
    
    model_ref = ModelReference(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationModel(TestOptModel, model_ref,
                        sys; optimizer = Cbc_optimizer,
                        parameters = true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 7861.641970967743,1.0)
    moi_tests(UC, true, 32, 0, 8, 4, 10, true)
end

#=
using PowerSystems
using JuMP
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir, "data/data_5bus_uc.jl"))
sys5 = PSY.System(nodes5, generators5, loads5_DA, branches5, nothing, 100.0);
using PowerSimulations
const PS = PowerSimulations

simple_reserve = PSY.StaticReserve("test_reserve", vcat(sys5.generators.thermal, sys5.generators.renewable[2]), 60.0, [gen.tech for gen in sys5.generators.thermal])
#simple_reserve = PSY.StaticReserve("test_reserve", sys5.generators.thermal, 60.0, [sys5.generators.thermal[1].tech])

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
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalStandardUnitCommitment , Net, sys5);
    PSI.construct_device!(m, netinjection, RenewableGen, PSI.RenewableCurtail, Net, sys5);
    PSI.construct_device!(m, netinjection, ElectricLoad, PSI.InterruptibleLoad, Net, sys5);
    PSI.construct_network!(m, [(device=Branch, formulation=PSI.PiLine)], netinjection, Net, sys5)
    PSI.construct_service!(m, simple_reserve, PSI.RampLimitedReserve, [(device = ThermalGen, formulation =PSI.ThermalStandardUnitCommitment ),
                                                              (device = RenewableGen, formulation = PSI.RenewableCurtail)],
                                                              sys5)
    m.obj_dict
true finally end
=#
