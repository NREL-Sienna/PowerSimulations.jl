using PowerSystems
using JuMP
using PowerSimulations
using Ipopt
const PS = PowerSimulations

# ED Testing
base_dir = dirname(dirname(pathof(PowerSystems)))
ps_dict = PSY.parsestandardfiles(abspath(joinpath(base_dir, "data/matpower/case5_dc.m")));
sys5 = PowerSystem(ps_dict);

solver = Ipopt.Optimizer

@test try

    ED = PSI.PowerOperationModel(PSI.EconomicDispatch,
        [(device = ThermalGen, formulation =PSI.ThermalDispatch)],
        nothing,
        nothing,
        [(device=Line, formulation=PSI.PiLine)],
        PSI.CopperPlatePowerModel,
        nothing,
        sys5,
        Model(),
        false,
        nothing)

    PSI.buildmodel!(sys5,ED)

    ED_sim = PSI.buildsimulation!(sys5, ED)

    PSI.run_simulations(ED_sim, solver, ps_dict)

true finally end
