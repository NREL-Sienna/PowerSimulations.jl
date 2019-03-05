@testset "Load Constructors" begin
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                                  Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                             "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                  Dict{String,Any}(),
                                      nothing);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Load Constructors" begin
    ps_model = PSI.CanonicalModel(Model(),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                                  Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                             "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                      Dict{String,Any}(),
                                      nothing);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.InterruptiblePowerLoad, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Load Constructors" begin
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                                "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                                                                Dict{String,Any}(),
                                                                                nothing);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.DCPlosslessForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end

@testset "Load Constructors" begin
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                                "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                                                                Dict{String,Any}(),
                                                                                nothing);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.StandardACPForm, sys5b, time_range);
    @test JuMP.num_variables(ps_model.JuMPmodel) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
end