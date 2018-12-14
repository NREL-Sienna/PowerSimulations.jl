ps_model = PS.canonical_model(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              Dict{String, PS.JumpAffineExpressionArray}("var_active" => PS.JumpAffineExpressionArray(undef, 14, 24),
                                                                         "var_reactive" => PS.JumpAffineExpressionArray(undef, 14, 24)),
                              Dict());

@test try PS.activepowervariables(ps_model, generators5, 1:24); true finally end
@test try PS.reactivepowervariables(ps_model, generators5, 1:24); true finally end
@test try PS.commitmentvariables(ps_model, generators5, 1:24); true finally end

@test try PS.activepowervariables(ps_model, renewables, 1:24); true finally end
@test try PS.reactivepowervariables(ps_model, renewables , 1:24); true finally end

@test try PS.activepowervariables(ps_model, generators_hg, 1:24); true finally end
@test try PS.reactivepowervariables(ps_model, generators_hg , 1:24); true finally end

@test try PS.activepowervariables(ps_model, battery, 1:24); true finally end
@test try PS.reactivepowervariables(ps_model, battery , 1:24); true finally end

@test try PS.activepowervariables(ps_model, loads5_DA, 1:24); true finally end
@test try PS.reactivepowervariables(ps_model, loads5_DA, 1:24); true finally end

@test try PS.flowvariables(ps_model, PS.DCAngleForm, branches5, 1:24); true finally end