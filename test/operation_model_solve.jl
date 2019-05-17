@testset "Solving ED Models" begin
    #5 Bus Test
    ED = EconomicDispatch(sys5, CopperPlatePowerModel; optimizer = GLPK_optimizer);
    res_5 = solve_op_model!(ED)
    @test isapprox(res_5.total_cost[:ED], 2400, atol = 1000)
    #14 Bus Test
    ED = EconomicDispatch(sys14, CopperPlatePowerModel; optimizer = OSQP_optimizer);
    res_14 = solve_op_model!(ED)
    @test isapprox(res_14.total_cost[:ED], 1000, atol = 100)
    #RTS Test
    #ED = EconomicDispatch(sys_rts, CopperPlatePowerModel; optimizer = GLPK_optimizer);
    #res_rts = solve_op_model!(ED)
end

@testset "Solving ED with PTDF Models" begin
    # 5 - Bus Test
    ED = EconomicDispatch(sys5, StandardPTDFForm; PTDF = PTDF5, optimizer = GLPK_optimizer);
    res_5 = solve_op_model!(ED)
    @test isapprox(res_5.total_cost[:ED], 3400, atol = 1000)

    ED = EconomicDispatch(sys5, StandardPTDFForm; PTDF = PTDF5, optimizer = GLPK_optimizer, parameters = false);
    res_5 = solve_op_model!(ED)
    @test isapprox(res_5.total_cost[:ED], 3400, atol = 1000)

    # 14 Bus Test
    ED = EconomicDispatch(sys14, StandardPTDFForm; PTDF = PTDF14, optimizer = OSQP_optimizer);
    res_14 = solve_op_model!(ED)
    @test isapprox(res_14.total_cost[:ED], 1000, atol = 100)

    ED = EconomicDispatch(sys14, StandardPTDFForm; PTDF = PTDF14, optimizer = OSQP_optimizer, parameters = false);
    res_14 = solve_op_model!(ED)
    @test isapprox(res_14.total_cost[:ED], 1000, atol = 100)
end



@testset "testing AngleDC-OPF 5-bus" begin
    # 5 - Bus Test
    ED = EconomicDispatch(sys5,PM.DCPlosslessForm; optimizer = GLPK_optimizer);
    res_5= solve_op_model!(ED)
    @test isapprox(res_5.total_cost[:ED], 3400, atol = 1000)

    ED = EconomicDispatch(sys5,PM.DCPlosslessForm; optimizer = GLPK_optimizer, parameters = false);
    res_5= solve_op_model!(ED)
    @test isapprox(res_5.total_cost[:ED], 3400, atol = 1000)

    # 14 - Bus Test
    ED = EconomicDispatch(sys14,PM.DCPlosslessForm; optimizer = ipopt_optimizer);
    res_14 = solve_op_model!(ED)
    @test isapprox(res_14.total_cost[:ED], 1000, atol = 100)

    ED = EconomicDispatch(sys14,PM.DCPlosslessForm; optimizer = ipopt_optimizer, parameters = false);
    res_14 = solve_op_model!(ED)
    @test isapprox(res_14.total_cost[:ED], 1000, atol = 100)
end

@testset "Test the equivelance of 5bus PM and PSI models" begin
     file = joinpath(dirname(dirname(pathof(PowerModels))),"test/data/matpower/case5.m")
     #ps5 = PowerSystems.parsestandardfiles(file) # this fails because PSY changes to mixed_units

     # adjusted standard file parsing without mixed units
     ps5 = PowerSystems.parse_file(file)
     #make_mixed_units(ps5)
     ps5 = PowerSystems.pm2ps_dict(ps5)
     # a single period simulation should be equivelant to a PM simulation
     for (k,l) in ps5["load"]
         l["scalingfactor"] = l["scalingfactor"][1]
     end
     bus5, gen5, stor5, branch5,load5,lz5,shunts5,service5 = ps_dict2ps_struct(ps5)
     sys5 = PSY.System(bus5,gen5,load5,branch5,stor5,100.0)
     ED5 = EconomicDispatch(sys5, PM.DCPlosslessForm; optimizer = ipopt_optimizer)
     res_5 = solve_op_model!(ED5)

     pm5 = PowerModels.parse_file(file)
     PM5 = build_generic_model(pm5,DCPPowerModel,PowerModels.post_opf)
     res_PM5 = solve_generic_model(PM5,ipopt_optimizer)

    @test isapprox(res_5.total_cost[:ED], res_PM5["objective"],atol = 1)
 end

  @testset "Test the equivelance of 14bus PM and PSI models" begin
     file = joinpath(dirname(dirname(pathof(PowerModels))),"test/data/matpower/case14.m")
     #ps14 = PowerSystems.parsestandardfiles(file) # this fails because PSY changes to mixed_units

      # adjusted stndard file parsing without mixed units
     ps14 = PowerSystems.parse_file(file)
     #make_mixed_units(ps14)
     ps14 = PowerSystems.pm2ps_dict(ps14)

      # a single period simulation should be equivelant to a PM simulation
     for (k,l) in ps14["load"]
         l["scalingfactor"] = l["scalingfactor"][1]
     end
     bus14, gen14, stor14, branch14,load14,lz14,shunts14,service14 = ps_dict2ps_struct(ps14)
     sys14 = PSY.System(bus14,gen14,load14,branch14,stor14,100.0)
     ED14 = EconomicDispatch(sys14, PM.DCPlosslessForm; optimizer = ipopt_optimizer)
     res_14 = solve_op_model!(ED14)

      pm14 = PowerModels.parse_file(file)
     PM14 = build_generic_model(pm14,DCPPowerModel,PowerModels.post_opf)
     res_PM14 = solve_generic_model(PM14,ipopt_optimizer)

      @test isapprox(res_14.total_cost[:ED], res_PM14["objective"], atol = 1)
 end

#=
@test try
    @info "testing ACP-OPF 5-bus"
    Net = PM.StandardACPForm
    m = Model(ipopt_optimizer);
    netinjection = instantiate_network(Net, sys5);
    construct_device!(m, netinjection, ThermalGen, ThermalDispatch, Net, sys5);
    construct_network!(m, [(device=Line, formulation=PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
true finally end

@test try
    @info "testing ACP- QCWForm 5-bus"
    Net = PM.QCWRForm
    m = Model(ipopt_optimizer);
    netinjection = instantiate_network(Net, sys5);
    construct_device!(m, netinjection, ThermalGen, ThermalDispatch, Net, sys5);
    construct_network!(m, [(device=Line, formulation=PiLine)], netinjection, Net, sys5)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 3400, atol = 1000)
true finally end

@test try
    @info "testing AngleDC-OPF 14-bus"
    Net = PM.DCPlosslessForm
    m = Model(ipopt_optimizer);
    netinjection = instantiate_network(Net, sys14);
    construct_device!(m, netinjection, ThermalGen, ThermalDispatch, Net, sys14);
    construct_network!(m, [(device=Line, formulation=PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
finally end

@test try
    @info "testing ACP-OPF 14-bus"
    Net = PM.StandardACPForm
    m = Model(ipopt_optimizer);
    netinjection = instantiate_network(Net, sys14);
    construct_device!(m, netinjection, ThermalGen, ThermalDispatch, Net, sys14);
    construct_network!(m, [(device=Line, formulation=PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
true finally end

@test try
    @info "testing ACP-QCWForm 14-bus"
    Net = PM.QCWRForm
    m = Model(ipopt_optimizer);
    netinjection = instantiate_network(Net, sys14);
    construct_device!(m, netinjection, ThermalGen, ThermalDispatch, Net, sys14);
    construct_network!(m, [(device=Line, formulation=PiLine)], netinjection, Net, sys14)
    JuMP.@objective(m, Min, m.obj_dict[:objective_function])
    JuMP.optimize!(m)
    isapprox(JuMP.objective_value(m), 1200, atol = 1000)
true finally end
=#