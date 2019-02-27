@test try
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                                  Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                             "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                  Dict{String,Any}(),
                                      nothing);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.DCPlosslessForm, sys5b);
    true finally end

    @test try
    ps_model = PSI.CanonicalModel(Model(),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                                  Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                             "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                      Dict{String,Any}(),
                                      nothing);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.StandardACPForm, sys5b);
    true finally end

@test try
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                                "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                                                                Dict{String,Any}(),
                                                                                nothing);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.DCPlosslessForm, sys5b);
    true finally end

    @test try
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                                "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                                                                Dict{String,Any}(),
                                                                                nothing);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.StandardACPForm, sys5b);
    true finally end