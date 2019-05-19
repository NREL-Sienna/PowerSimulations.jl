@testset "Solving ED with CopperPlate" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.StandardThermal, PSI.ThermalDispatch),
                                        :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, DeviceModel}()
    services = Dict{Symbol, PSI.ServiceModel}()
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);

    parameters_value = [true, false]

    for p in parameters_value
        @info("Testing ED CopperPlatePowerModel solve")
        @testset "ED CopperPlatePowerModel model parameters = $(p)" begin
        ED = OperationModel(TestOptModel, model_ref, c_sys5; optimizer = GLPK_optimizer, parameters = p)
        res_5 = solve_op_model!(ED)
        @test termination_status(ED.canonical_model.JuMPmodel) == MOI.OPTIMAL
        @test isapprox(res_5.total_cost[:OBJECTIVE_FUNCTION], 240000, atol = 10000)
        #14 Bus Test
        #ED = OperationModel(TestOptModel, model_ref, c_sys14; optimizer = OSQP_optimizer, parameters = p);
        #res_14 = solve_op_model!(ED)
        #@test termination_status(ED.canonical_model.JuMPmodel) == MOI.OPTIMAL
        #@test isapprox(res_14.total_cost[:OBJECTIVE_FUNCTION], 120000, atol = 10000)
        end
    end
    #RTS Test
    #ED = EconomicDispatch(sys_rts, CopperPlatePowerModel; optimizer = GLPK_optimizer);
    #res_rts = solve_op_model!(ED)
end

@testset "Solving ED with PTDF Models" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.StandardThermal, PSI.ThermalDispatch),
                                        :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, DeviceModel}()
    services = Dict{Symbol, PSI.ServiceModel}()
    model_ref = ModelReference(StandardPTDFForm, devices, branches, services);
    parameters_value = [true, false]

    for p in parameters_value
        @info("Testing ED StandardPTDFForm solve")
        @testset "ED StandardPTDFForm model parameters = $(p)" begin
        #ED = OperationModel(TestOptModel, model_ref, c_sys5; PTDF = PTDF5, optimizer = GLPK_optimizer, parameters = p)
        #res_5 = solve_op_model!(ED)
        #@test termination_status(ED.canonical_model.JuMPmodel) == MOI.OPTIMAL
        #@test isapprox(res_5.total_cost[:OBJECTIVE_FUNCTION], 240000, atol = 10000)
        #14 Bus Test
        ED = OperationModel(TestOptModel, model_ref, c_sys14; PTDF = PTDF14, optimizer = OSQP_optimizer, parameters = p);
        res_14 = solve_op_model!(ED)
        @test termination_status(ED.canonical_model.JuMPmodel) == MOI.OPTIMAL
        @test isapprox(res_14.total_cost[:OBJECTIVE_FUNCTION], 120000, atol = 15000)
        end
    end
end


@testset "Solving ED With PowerModels Networks" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.StandardThermal, PSI.ThermalDispatch),
                                        :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
    branches5 = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.ACSeriesBranch))
    branches14 = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.ACSeriesBranch),
                                           :T => DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch),
                                           :TT => DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch))
    services = Dict{Symbol, PSI.ServiceModel}()
    parameters_value = [true, false]
    networks = [PM.DCPlosslessForm,
                PM.NFAForm,
                PM.StandardACPForm,
                #PM.StandardACRForm,
                PM.StandardACTForm,
                PM.StandardDCPLLForm,
                PM.AbstractLPACCForm,
                PM.SOCWRForm,
                PM.QCWRForm,
                PM.QCWRTriForm]

    for  net in networks, p in parameters_value
        @info("Testing ED $(net) solve")
        @testset "ED model $(net) and parameters = $(p)" begin
        model_ref5 = ModelReference(net, devices, branches5, services);
        #ED = OperationModel(TestOptModel, model_ref5, c_sys5; optimizer = ipopt_optimizer, parameters = p)
        #res_5 = solve_op_model!(ED)
        #@test isapprox(res_5.total_cost[:OBJECTIVE_FUNCTION], 325000, atol = 25000)
        #@test termination_status(ED.canonical_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        #14 Bus Test
        model_ref14 = ModelReference(net, devices, branches14, services);
        ED = OperationModel(TestOptModel, model_ref14, c_sys14; optimizer = ipopt_optimizer, parameters = p);
        res_14 = solve_op_model!(ED)
        @test isapprox(res_14.total_cost[:OBJECTIVE_FUNCTION], 120000, atol = 10000)
        @test termination_status(ED.canonical_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        end
    end

end

@testset "Solving UC Linear Networks" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.StandardThermal, PSI.ThermalUnitCommitment),
                                        :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
    branches5 = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.ACSeriesBranch))
    branches14 = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.ACSeriesBranch),
                                           :T => DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch),
                                           :TT => DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch))
    services = Dict{Symbol, PSI.ServiceModel}()
    parameters_value = [true, false]
    networks = [PM.DCPlosslessForm,
                PM.NFAForm,
                StandardPTDFForm,
                CopperPlatePowerModel]

    for  net in networks, p in parameters_value
        @info("Testing UC $(net) solve")
        @testset "UC model $(net) and parameters = $(p)" begin
        model_ref5 = ModelReference(net, devices, branches5, services);
        UC = OperationModel(TestOptModel, model_ref5, c_sys5; PTDF = PTDF5, optimizer = GLPK_optimizer, parameters = p)
        res_5 = solve_op_model!(UC)
        @test termination_status(UC.canonical_model.JuMPmodel) == MOI.OPTIMAL
        if net != CopperPlatePowerModel
            @test isapprox(res_5.total_cost[:OBJECTIVE_FUNCTION], 340000, atol = 100000)
        else
            @test isapprox(res_5.total_cost[:OBJECTIVE_FUNCTION], 240000, atol = 100000)

        end
        end
    end

end

#=
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

    @test isapprox(res_5.total_cost[:OBJECTIVE_FUNCTION], res_PM5["objective"],atol = 1)
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

      @test isapprox(res_14.total_cost[:OBJECTIVE_FUNCTION], res_PM14["objective"], atol = 1)
 end
 =#