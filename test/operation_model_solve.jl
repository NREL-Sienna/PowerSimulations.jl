

@testset "Solving ED Models" begin
    ED = PSI.EconomicDispatch(sys5b_uc, PSI.CopperPlatePowerModel; optimizer = GLPK_optimizer);
    res_5 = solve_op_model!(ED)
    @test isapprox(res_5.total_cost[:ED], 2400, atol = 1000)
    ED = PSI.EconomicDispatch(sys14, PSI.CopperPlatePowerModel; optimizer = ipopt_optimizer);
    res_14 = solve_op_model!(ED)
    @test isapprox(res_14.total_cost[:ED], 1000, atol = 100)
end

@testset "Solving ED with PTDF Models" begin
    PTDF5,  = PowerSystems.buildptdf(branches5, nodes5)
    ED = PSI.EconomicDispatch(sys5b_uc, PSI.StandardPTDFForm; PTDF = PTDF5, optimizer = GLPK_optimizer);
    res_5 = solve_op_model!(ED)
    @test isapprox(res_5.total_cost[:ED], 3400, atol = 1000)
    PTDF14,  = PSY.buildptdf(sys14.branches, sys14.buses)
    ED = PSI.EconomicDispatch(sys14, PSI.StandardPTDFForm; PTDF = PTDF14, optimizer = ipopt_optimizer);
    res_14 = solve_op_model!(ED)
    @test_skip isapprox(res_14.total_cost[:ED], 1300, atol = 100)
end



@testset "testing AngleDC-OPF 5-bus" begin
    ED = PSI.EconomicDispatch(sys5b_uc,PM.DCPlosslessForm; optimizer = GLPK_optimizer);
    res_5= solve_op_model!(ED)
    @test isapprox(res_5.total_cost[:ED], 3400, atol = 1000)
    ED = PSI.EconomicDispatch(sys14,PM.DCPlosslessForm; optimizer = ipopt_optimizer);
    res_14 = solve_op_model!(ED)
    @test isapprox(res_14.total_cost[:ED], 1300, atol = 100)
end

#=
@test try
    @info "testing ACP-OPF 5-bus"
    Net = PM.StandardACPForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
    PSI.construct_network!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
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
    PSI.construct_network!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
true finally end

@test try
    @info "testing AngleDC-OPF 14-bus"
    Net = PM.DCPlosslessForm
    m = Model(ipopt_optimizer);
    netinjection = PSI.instantiate_network(Net, sys14);
    PSI.construct_device!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys14);
    PSI.construct_network!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
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
    PSI.construct_network!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
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
    PSI.construct_network!(m, [(device=Line, formulation=PSI.PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
true finally end
=#