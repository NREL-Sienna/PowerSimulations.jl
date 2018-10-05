using PowerSystems
using JuMP
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  1000.0);
using PowerSimulations
const PS = PowerSimulations

simple_reserve = PowerSystems.StaticReserve("test_reserve",sys5.generators.thermal,60.0,[gen.tech for gen in sys5.generators.thermal])

@test try
    ED = PS.PowerOperationModel(PS.EconomicDispatch, 
                            [(device = ThermalGen, formulation =PS.ThermalDispatch)], 
                            [(device = ElectricLoad, formulation = PS.InterruptibleLoad)],
                            nothing, 
                            [(device=Line, formulation=PS.PiLine)],
                            PS.CopperPlatePowerModel,
                            [simple_reserve], 
                            sys5,
                            Model(), 
                            false)
    PS.buildmodel!(ED)
    ED.model.obj_dict
    #JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
true finally end
