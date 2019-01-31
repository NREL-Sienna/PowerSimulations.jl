ps_model = PSI.CanonicalModel(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                              Dict());

@test  try
    PSI.activepowervariables(ps_model, generators5, 1:24)
    PSI.activepower(ps_model, generators5, PSI.ThermalDispatch, PM.DCPlosslessForm, 1:24)
    PSI.reactivepowervariables(ps_model, generators5, 1:24)
    PSI.reactivepower(ps_model, generators5, PSI.ThermalDispatch, PM.StandardACPForm, 1:24)
true finally end

@test  try
    PSI.activepowervariables(ps_model, generators5, 1:24)
    PSI.commitmentvariables(ps_model, generators5, 1:24);
    PSI.activepower(ps_model, generators5, PSI.ThermalUnitCommitment , PM.DCPlosslessForm, 1:24)
    PSI.reactivepowervariables(ps_model, generators5, 1:24)
    PSI.reactivepower(ps_model, generators5, PSI.ThermalUnitCommitment , PM.StandardACPForm, 1:24)
true finally end

@test_skip  try
    PSI.activepowervariables(ps_model, generators_hg, 1:24)
    PSI.activepower(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.DCPlosslessForm, 1:24)
    PSI.activepower(ps_model, generators_hg, PSI.HydroFullDispatch, PM.DCPlosslessForm, 1:24)
    PSI.activepower(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.StandardACPForm, 1:24)
    PSI.reactivepowervariables(ps_model, generators_hg, 1:24)
    PSI.reactivepower(ps_model, generators_hg, PSI.HydroDispatchRunOfRiver, PM.StandardACPForm, 1:24)
true finally end

@test_skip  try
    PSI.activepowervariables(ps_model, generators_hg, 1:24)
    PSI.commitmentvariables(ps_model, generators_hg, 1:24);
    PSI.activepower(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.DCPlosslessForm, 1:24)
    PSI.activepower(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.StandardACPForm, 1:24)
    PSI.reactivepowervariables(ps_model, generators_hg, 1:24)
    PSI.reactivepower(ps_model, generators_hg, PSI.HydroCommitmentRunOfRiver, PM.StandardACPForm, 1:24)
true finally end

@test  try
    PSI.activepowervariables(ps_model, renewables, 1:24)
    PSI.reactivepowervariables(ps_model, renewables, 1:24)
    PSI.activepower(ps_model, renewables, PSI.RenewableFullDispatch, PM.DCPlosslessForm, 1:24)
    PSI.reactivepower(ps_model, renewables, PSI.RenewableConstantPowerFactor, PM.StandardACPForm, 1:24)
    #TODO: Missing a test for full dispatch since there is no data for this case yet in the example files
true finally end


@test  try
    PSI.activepowervariables(ps_model, loads5_DA, 1:24)
    PSI.reactivepowervariables(ps_model, loads5_DA, 1:24)
    PSI.activepower(ps_model,  loads5_DA, PSI.InterruptiblePowerLoad,  PM.DCPlosslessForm, 1:24)
    PSI.activepower(ps_model,  loads5_DA, PSI.InterruptiblePowerLoad,  PM.StandardACPForm, 1:24)
    PSI.reactivepower(ps_model,  loads5_DA, PSI.InterruptiblePowerLoad, PM.StandardACPForm, 1:24)
    #TODO: Missing a test for full dispatch since there is no data for this case yet in the example files
true finally end