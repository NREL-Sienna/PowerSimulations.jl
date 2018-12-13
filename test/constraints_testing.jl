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
    PS.activepowervariables(ps_model, generators_hg, 1:24)
    PS.activepower(ps_model, generators_hg, PS.HydroCurtailment, PS.DCAngleForm, 1:24)
    PS.reactivepowervariables(ps_model, generators_hg, 1:24)
    PS.reactivepower(ps_model, generators_hg, PS.HydroCurtailment, PS.StandardAC, 1:24)
true finally end