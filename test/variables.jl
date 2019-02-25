ps_model = PSI.CanonicalModel(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);

@test try PSI.activepower_variables(ps_model, generators5, 1:24); true finally end
@test try PSI.reactivepower_variables(ps_model, generators5, 1:24); true finally end
@test try PSI.commitment_variables(ps_model, generators5, 1:24); true finally end

@test try PSI.activepower_variables(ps_model, renewables, 1:24); true finally end
@test try PSI.reactivepower_variables(ps_model, renewables , 1:24); true finally end

@test try PSI.activepower_variables(ps_model, generators_hg, 1:24); true finally end
@test try PSI.reactivepower_variables(ps_model, generators_hg , 1:24); true finally end

@test try PSI.activepower_variables(ps_model, battery, 1:24); true finally end
@test try PSI.reactivepower_variables(ps_model, battery , 1:24); true finally end

@test try PSI.activepower_variables(ps_model, loads5_DA, 1:24); true finally end
@test try PSI.reactivepower_variables(ps_model, loads5_DA, 1:24); true finally end

@test try PSI.flow_variables(ps_model, PM.DCPlosslessForm, branches5, 1:24); true finally end