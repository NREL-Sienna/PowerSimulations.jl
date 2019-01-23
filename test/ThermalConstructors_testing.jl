
@test try 
ps_model = PSI.CanonicalModel(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                              Dict());
constructdevice!(ps_model PSY.ThermalGen, PSI.ThermalUnitCommitment, PM.DCPlosslessForm, sys14);
true finally end

@test try 
ps_model = PSI.CanonicalModel(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                              Dict());
constructdevice!(ps_model PSY.ThermalGen, PSI.ThermalUnitCommitment, PM.StandardACPForm, sys14); 
true finally end

@test try 
    ps_model = PSI.CanonicalModel(Model(),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                                  Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                             "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                                  Dict());
    constructdevice!(ps_model PSY.ThermalGen, PSI.ThermalDispatch, PM.DCPlosslessForm, sys14);
    true finally end
    
    @test try 
    ps_model = PSI.CanonicalModel(Model(),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                                  Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                             "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                                  Dict());
    constructdevice!(ps_model PSY.ThermalGen, PSI.ThermalDispatch, PM.StandardACPForm, sys14); 
    true finally end