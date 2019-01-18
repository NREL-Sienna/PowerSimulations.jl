ps_model = PSI.CanonicalModel(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                              Dict());

@test  try
    PSI.activepowervariables(ps_model, generators5, 1:24)
    PSI.activepower(ps_model, generators5, PSI.ThermalDispatch, PSI.DCAngleForm, 1:24)
    PSI.reactivepowervariables(ps_model, generators5, 1:24)
    PSI.reactivepower(ps_model, generators5, PSI.ThermalDispatch, PSI.StandardAC, 1:24)
true finally end

@test  try
    PSI.activepowervariables(ps_model, generators5, 1:24)
    PSI.commitmentvariables(ps_model, generators5, 1:24);
    PSI.activepower(ps_model, generators5, PSI.StandardThermalCommitment, PSI.DCAngleForm, 1:24)
    PSI.reactivepowervariables(ps_model, generators5, 1:24)
    PSI.reactivepower(ps_model, generators5, PSI.StandardThermalCommitment, PSI.StandardAC, 1:24)
true finally end

@test  try
    PSI.activepowervariables(ps_model, generators_hg, 1:24)
    PSI.activepower(ps_model, generators_hg, PSI.HydroRunOfRiver, PSI.DCAngleForm, 1:24)
    PSI.activepower(ps_model, generators_hg, PSI.HydroFullDispatch, PSI.DCAngleForm, 1:24)
    PSI.activepower(ps_model, generators_hg, PSI.HydroRunOfRiver, PSI.StandardAC, 1:24)
    PSI.reactivepowervariables(ps_model, generators_hg, 1:24)
    PSI.reactivepower(ps_model, generators_hg, PSI.HydroRunOfRiver, PSI.StandardAC, 1:24)
true finally end

@test  try
    PSI.activepowervariables(ps_model, generators_hg, 1:24)
    PSI.commitmentvariables(ps_model, generators_hg, 1:24);
    PSI.activepower(ps_model, generators_hg, PSI.HydroCommitment, PSI.DCAngleForm, 1:24)
    PSI.activepower(ps_model, generators_hg, PSI.HydroCommitment, PSI.StandardAC, 1:24)
    PSI.reactivepowervariables(ps_model, generators_hg, 1:24)
    PSI.reactivepower(ps_model, generators_hg, PSI.HydroCommitment, PSI.StandardAC, 1:24)
true finally end

@test  try
    PSI.activepowervariables(ps_model, renewables, 1:24)
    PSI.reactivepowervariables(ps_model, renewables, 1:24)
    PSI.activepower(ps_model, renewables, PSI.RenewableFullDispatch, PSI.DCAngleForm, 1:24)
    PSI.reactivepower(ps_model, renewables, PSI.RenewableConstantPowerFactor, PSI.StandardAC, 1:24)
    #TODO: Missing a test for full dispatch since there is no data for this case yet in the example files
true finally end


@test  try
    PSI.activepowervariables(ps_model, loads5_DA, 1:24)
    PSI.reactivepowervariables(ps_model, loads5_DA, 1:24)
    PSI.activepower(ps_model,  loads5_DA, PSI.FullControllablePowerLoad,  PSI.DCAngleForm, 1:24)
    PSI.activepower(ps_model,  loads5_DA, PSI.FullControllablePowerLoad,  PSI.StandardAC, 1:24)
    PSI.reactivepower(ps_model,  loads5_DA, PSI.FullControllablePowerLoad, PSI.StandardAC, 1:24)
    #TODO: Missing a test for full dispatch since there is no data for this case yet in the example files
true finally end