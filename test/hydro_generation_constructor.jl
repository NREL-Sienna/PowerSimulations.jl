@testset " Hydro Tests" begin
    PSI.activepower_variables(ps_model, generators_hg, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.DCPlosslessForm, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.StandardACPForm, 1:24)
    PSI.reactivepower_variables(ps_model, generators_hg, 1:24)
    PSI.reactivepower_constraints(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.StandardACPForm, 1:24)
end

@testset " Hydro Tests" begin
    ps_model = PSI._ps_model_init(sys5b, nothing, PM.AbstractPowerFormulation, sys5b.time_periods)
    PSI.activepower_variables(ps_model, generators_hg, 1:24)
    PSI.commitment_variables(ps_model, generators_hg, 1:24);
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.DCPlosslessForm, 1:24)
    PSI.activepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.StandardACPForm, 1:24)
    PSI.reactivepower_variables(ps_model, generators_hg, 1:24)
    PSI.reactivepower_constraints(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.StandardACPForm, 1:24)
end