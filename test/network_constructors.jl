@test try
    @info "testing copper plate network construction"
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
    Dict{String, JuMP.Containers.DenseAxisArray}(),
    nothing,
    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                               "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
    Dict{String,Any}(),
    nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PSI.CopperPlatePowerModel, sys5b);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PSI.CopperPlatePowerModel, sys5b);
    PSI.constructnetwork!(ps_model, PSI.CopperPlatePowerModel, sys5b);
    JuMP.num_variables(ps_model.JuMPmodel) == 120
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    if termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
        @info("The model has ans optimal solution.")
    elseif termination_status(ps_model.JuMPmodel) == MOI.TIME_LIMIT && has_values(ps_model.JuMPmodel)
        @info("The model has feasiable but non-optimal solutions.")
    else
        error("The model was not solved correctly/infeasible.")
    end

true finally end

@test try
    @info "testing DC-PF with PTDF formulation"
    PTDF, A = PowerSystems.buildptdf(branches5, nodes5)
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
    Dict{String, JuMP.Containers.DenseAxisArray}(),
    nothing,
    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                               "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
    Dict{String,Any}(),
    nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PSI.StandardPTDFModel, sys5b);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PSI.StandardPTDFModel, sys5b);
    PSI.constructnetwork!(ps_model, PSI.StandardPTDFModel, sys5b; PTDF = PTDF)
    JuMP.num_variables(ps_model.JuMPmodel) == 264
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    if termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
        @info("The model has ans optimal solution.")
    elseif termination_status(ps_model.JuMPmodel) == MOI.TIME_LIMIT && has_values(ps_model.JuMPmodel)
        @info("The model has feasiable but non-optimal solutions.")
    else
        error("The model was not solved correctly/infeasible.")
    end
true finally end


@test_throws ArgumentError try
    @info "testing error PTDF formulation with no PTDF supplied"
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
    Dict{String, JuMP.Containers.DenseAxisArray}(),
    nothing,
    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                               "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
    Dict{String,Any}(),
    nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PSI.StandardPTDFModel, sys5b);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PSI.StandardPTDFModel, sys5b);
    PSI.constructnetwork!(ps_model, PSI.StandardPTDFModel, sys5b)
    JuMP.num_variables(ps_model.JuMPmodel) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 0

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    if termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
        @info("The model has ans optimal solution.")
    elseif termination_status(ps_model.JuMPmodel) == MOI.TIME_LIMIT && has_values(ps_model.JuMPmodel)
        @info("The model has feasiable but non-optimal solutions.")
    else
        error("The model was not solved correctly/infeasible.")
    end
true finally end

@test try
    @info "testing DC-PF network construction"
    ps_model = PSI.CanonicalModel(Model(GLPK_optimizer),
    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
    Dict{String, JuMP.Containers.DenseAxisArray}(),
    nothing,
    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                               "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
    Dict{String,Any}(),
    nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.DCPlosslessForm, sys5b);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.DCPlosslessForm, sys5b);
    PSI.constructnetwork!(ps_model, PM.DCPlosslessForm, sys5b);
    JuMP.num_variables(ps_model.JuMPmodel) == 384
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 288

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    if termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
        @info("The model has ans optimal solution.")
    elseif termination_status(ps_model.JuMPmodel) == MOI.TIME_LIMIT && has_values(ps_model.JuMPmodel)
        @info("The model has feasiable but non-optimal solutions.")
    else
        error("The model was not solved correctly/infeasible.")
    end
true finally end

@test try
    @info "testing AC-PF network construction"
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
    Dict{String, JuMP.Containers.DenseAxisArray}(),
    nothing,
    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                               "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
    Dict{String,Any}(),
    nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.StandardACPForm, sys5b);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.StandardACPForm, sys5b);
    PSI.constructnetwork!(ps_model, PM.StandardACPForm, sys5b);
    JuMP.num_variables(ps_model.JuMPmodel) == 1056
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 144
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 144
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 264

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    if termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
        @info("The model has ans optimal solution.")
    elseif termination_status(ps_model.JuMPmodel) == MOI.TIME_LIMIT && has_values(ps_model.JuMPmodel)
        @info("The model has feasiable but non-optimal solutions.")
    else
        error("The model was not solved correctly/infeasible.")
    end
true finally end

@test try
    @info "testing AC-PF network construction with QCWRForm"
    ps_model = PSI.CanonicalModel(Model(ipopt_optimizer),
    Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
    Dict{String, JuMP.Containers.DenseAxisArray}(),
    nothing,
    Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                               "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
    Dict{String,Any}(),
    nothing);
    PSI.construct_device!(ps_model, PSY.ThermalGen, PSI.ThermalDispatch, PM.QCWRForm, sys5b);
    PSI.construct_device!(ps_model, PSY.PowerLoad, PSI.StaticPowerLoad, PM.QCWRForm, sys5b);
    PSI.constructnetwork!(ps_model, PM.QCWRForm, sys5b);
    JuMP.num_variables(ps_model.JuMPmodel) == 2184
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 1272
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 1584
    JuMP.num_constraints(ps_model.JuMPmodel,GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 1128

    JuMP.@objective(ps_model.JuMPmodel, Min, AffExpr(0))
    JuMP.optimize!(ps_model.JuMPmodel)

    if termination_status(ps_model.JuMPmodel) == MOI.OPTIMAL
        @info("The model has ans optimal solution.")
    elseif termination_status(ps_model.JuMPmodel) == MOI.TIME_LIMIT && has_values(ps_model.JuMPmodel)
        @info("The model has feasiable but non-optimal solutions.")
    else
        error("The model was not solved correctly/infeasible.")
    end
true finally end

#=
@test try
    @info "testing net flow"
    Net = PSI.StandardNetFlow
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

@test try
    @info "testing PTDF 5-bus"
    Net = PSI.StandardPTDFModel
    m = Model(ipopt_optimizer);
    ptdf,  A = PSY.buildptdf(sys5.branches, sys5.buses)
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5, PTDF = ptdf)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

@test try
    @info "testing AngleDC-OPF 5-bus"
    Net = PM.DCPlosslessForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
finally end

@test try
    @info "testing ACP-OPF 5-bus"
    Net = PM.StandardACPForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
true finally end

@test try
    @info "testing ACP- QCWForm 5-bus"
    Net = PM.QCWRForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
true finally end



include(joinpath(base_dir,"data/data_14bus_pu.jl"))
sys14 = PowerSystem(nodes14, generators14, loads14, branches14, nothing,  100.0);


@test try
    @info "testing copper plate 14-bus"
    Net = PSI.CopperPlatePowerModel
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end


@test try
    @info "testing net 14-bus"
    Net = PSI.StandardNetFlow
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end


@test_skip try
    @info "testing PTDF 14-bus"
    Net = PSI.StandardPTDFModel
    m = Model(ipopt_optimizer);
    ptdf,  A = PSY.buildptdf(sys14.branches, sys14.buses)
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14, PTDF = ptdf)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

@test try
    @info "testing AngleDC-OPF 14-bus"
    Net = PM.DCPlosslessForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

@test try
    @info "testing ACP-OPF 14-bus"
    Net = PM.StandardACPForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
true finally end

@test try
    @info "testing ACP-QCWForm 14-bus"
    Net = PM.QCWRForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.constructnetwork!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
true finally end
=#