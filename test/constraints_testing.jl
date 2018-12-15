ps_model = PS.canonical_model(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              Dict{String, PS.JumpAffineExpressionArray}("var_active" => PS.JumpAffineExpressionArray(undef, 14, 24),
                                                                         "var_reactive" => PS.JumpAffineExpressionArray(undef, 14, 24)),
                              Dict());

@test  try
    PS.activepowervariables(ps_model, generators5, 1:24)
    PS.activepower(ps_model, generators5, PS.ThermalDispatch, PS.DCAngleForm, 1:24)
    PS.reactivepowervariables(ps_model, generators5, 1:24)
    PS.reactivepower(ps_model, generators5, PS.ThermalDispatch, PS.StandardAC, 1:24)
true finally end

@test  try
    PS.activepowervariables(ps_model, generators5, 1:24)
    PS.commitmentvariables(ps_model, generators5, 1:24);
    PS.activepower(ps_model, generators5, PS.StandardThermalCommitment, PS.DCAngleForm, 1:24)
    PS.reactivepowervariables(ps_model, generators5, 1:24)
    PS.reactivepower(ps_model, generators5, PS.StandardThermalCommitment, PS.StandardAC, 1:24)
true finally end

@test  try
    PS.activepowervariables(ps_model, generators_hg, 1:24)
    PS.activepower(ps_model, generators_hg, PS.HydroRunOfRiver, PS.DCAngleForm, 1:24)
    PS.activepower(ps_model, generators_hg, PS.HydroFullDispatch, PS.DCAngleForm, 1:24)
    PS.activepower(ps_model, generators_hg, PS.HydroRunOfRiver, PS.StandardAC, 1:24)
    PS.reactivepowervariables(ps_model, generators_hg, 1:24)
    PS.reactivepower(ps_model, generators_hg, PS.HydroRunOfRiver, PS.StandardAC, 1:24)
true finally end

@test  try
    PS.activepowervariables(ps_model, generators_hg, 1:24)
    PS.commitmentvariables(ps_model, generators_hg, 1:24);
    PS.activepower(ps_model, generators_hg, PS.HydroCommitment, PS.DCAngleForm, 1:24)
    PS.activepower(ps_model, generators_hg, PS.HydroCommitment, PS.StandardAC, 1:24)
    PS.reactivepowervariables(ps_model, generators_hg, 1:24)
    PS.reactivepower(ps_model, generators_hg, PS.HydroCommitment, PS.StandardAC, 1:24)
true finally end

@test  try
    PS.activepowervariables(ps_model, renewables, 1:24)
    PS.reactivepowervariables(ps_model, renewables, 1:24)
    PS.activepower(ps_model, renewables, PS.RenewableFullDispatch, PS.DCAngleForm, 1:24)
    PS.reactivepower(ps_model, renewables, PS.RenewableConstantPowerFactor, PS.StandardAC, 1:24)
    #TODO: Missing a test for full dispatch since there is no data for this case yet in the example files
true finally end


@test  try
    PS.activepowervariables(ps_model, loads5_DA, 1:24)
    PS.reactivepowervariables(ps_model, loads5_DA, 1:24)
    PS.activepower(ps_model,  loads5_DA, PS.FullControllablePowerLoad,  PS.DCAngleForm, 1:24)
    PS.activepower(ps_model,  loads5_DA, PS.FullControllablePowerLoad,  PS.StandardAC, 1:24)
    PS.reactivepower(ps_model,  loads5_DA, PS.FullControllablePowerLoad, PS.StandardAC, 1:24)
    #TODO: Missing a test for full dispatch since there is no data for this case yet in the example files
true finally end