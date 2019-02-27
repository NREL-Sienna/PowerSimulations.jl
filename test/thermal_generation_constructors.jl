@test try
    @info "testing UC With DC - PF"
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalUnitCommitment, PM.DCPlosslessForm, sys5b_uc);
    JuMP.num_variables(ps_model.JuMPmodel) == 480
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 120
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 120
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
true finally end

@test try
    @info "testing UC With AC - PF"
    ps_model = PSI.CanonicalModel(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalUnitCommitment, PM.StandardACPForm, sys5b_uc);
    JuMP.num_variables(ps_model.JuMPmodel) == 600
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 240
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 240
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 120
true finally end

@test try
    @info "testing Dispatch With DC - PF"
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.DCPlosslessForm, sys5b_uc);
    JuMP.num_variables(ps_model.JuMPmodel) == 120
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0
    true finally end

@test try
    @info "testing Dispatch With AC - PF"
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                                  Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                  Dict{String, JuMP.Containers.DenseAxisArray}(),
                                  nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.StandardACPForm, sys5b_uc);
    JuMP.num_variables(ps_model.JuMPmodel) == 240
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0   
    true finally end

@test try
    @info "testing Dispatch No-Minimum With DC - PF"
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatchNoMin, PM.DCPlosslessForm, sys5b_uc);
    JuMP.num_variables(ps_model.JuMPmodel) == 120
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0       
    true finally end

@test try
    @info "testing Dispatch No-Minimum With AC - PF"
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatchNoMin, PM.StandardACPForm, sys5b_uc);
    JuMP.num_variables(ps_model.JuMPmodel) == 240
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0       
    true finally end

@test try
    @info "testing Dispatch No-Minimum With DC - PF"
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                            "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                Dict{String,Any}(),
                                nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatchNoMin, PM.DCPlosslessForm, sys5b_uc);
    JuMP.num_variables(ps_model.JuMPmodel) == 120
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0   
    true finally end

@test try
    @info "testing Ramp Limited Dispatch With AC - PF"
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                            "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                Dict{String,Any}(),
                                nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalRampLimited, PM.StandardACPForm, sys5b_uc);
    JuMP.num_variables(ps_model.JuMPmodel) == 240
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0  
    true finally end

@test try
    @info "testing Ramp Limited Dispatch With AC - PF"
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
                                    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                                    Dict{String, JuMP.Containers.DenseAxisArray}(),
                                    nothing,
                                Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                            "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                                Dict{String,Any}(),
                                nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalRampLimited, PM.DCPlosslessForm, sys5b_uc);
    JuMP.num_variables(ps_model.JuMPmodel) == 120
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0  
    true finally end
