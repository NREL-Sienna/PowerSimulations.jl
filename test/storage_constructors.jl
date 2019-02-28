@test try
    @info "testing Abstract Storage With DC - PF"
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.Storage, PSI.AbstractStorageForm, PM.DCPlosslessForm, sys5b_storage);
    JuMP.num_variables(ps_model.JuMPmodel) == 96
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 48
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 48
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
true finally end

@test try
    @info "testing Abstract Storage With AC - PF"
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.Storage, PSI.AbstractStorageForm, PM.StandardACPForm, sys5b_storage);
    JuMP.num_variables(ps_model.JuMPmodel) == 120
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 48
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 48
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
true finally end

@test try
    @info "testing Basic Storage With DC - PF"
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.Storage, PSI.BookKeepingModel, PM.DCPlosslessForm, sys5b_storage);
    JuMP.num_variables(ps_model.JuMPmodel) == 96
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 48
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 48
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
    true finally end

@test try
    @info "testing Basic Storage With AC - PF"
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.Storage, PSI.BookKeepingModel, PM.StandardACPForm, sys5b_storage);
    JuMP.num_variables(ps_model.JuMPmodel) == 120
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 48
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 48
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
    true finally end
