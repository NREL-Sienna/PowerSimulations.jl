using PowerSystems
using JuMP
using PowerSimulations
using Ipopt
const PS = PowerSimulations

# ED Testing
base_dir = dirname(dirname(pathof(PowerSystems)))
ps_dict = PowerSystems.parsestandardfiles(abspath(joinpath(base_dir, "data/matpower/case5_dc.m")));
sys5 = PowerSystem(ps_dict);

solver = Ipopt.Optimizer

@test try

    ED = PS.PowerOperationModel(PS.EconomicDispatch,
        [(device = ThermalGen, formulation =PS.ThermalDispatch)],
        nothing,
        nothing,
        [(device=Line, formulation=PS.PiLine)],
        PS.CopperPlatePowerModel,
        nothing,
        sys5,
        Model(),
        false,
        nothing)

    PS.buildmodel!(sys5,ED)

    ED_sim = PS.buildsimulation!(sys5, ED)

    PS.run_simulations(ED_sim, solver, ps_dict)

true finally end
