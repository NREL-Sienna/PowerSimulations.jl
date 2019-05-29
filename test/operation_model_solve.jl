devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.ACSeriesBranch),
                                     :T => DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch),
                                     :TT => DeviceModel(PSY.TapTransformer , PSI.ACSeriesBranch))
services = Dict{Symbol, PSI.ServiceModel}()

@testset "Solving ED with CopperPlate" begin
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    parameters_value = [true, false]
    systems = [c_sys5, c_sys14]
    test_results = Dict{PSY.System, Float64}(c_sys5 => 240000.0,  
                                             c_sys14 => 120000.0)
    for sys in systems, p in parameters_value
        @info("Testing ED CopperPlatePowerModel solve")
        @testset "ED CopperPlatePowerModel model parameters = $(p)" begin
        ED = OperationModel(TestOptModel, model_ref, sys; optimizer = OSQP_optimizer, parameters = p)
        res = solve_op_model!(ED)
        @test termination_status(ED.canonical_model.JuMPmodel) == MOI.OPTIMAL
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], test_results[sys], atol = 10000)
        end
    end
end

@testset "Solving ED with PTDF Models" begin
    model_ref = ModelReference(StandardPTDFForm, devices, branches, services);
    parameters_value = [true, false]
    systems = [c_sys5, c_sys14]
    PTDF_ref = Dict{PSY.System, PSY.PTDF}(c_sys5 => PTDF5, c_sys14 => PTDF14)
    test_results = Dict{PSY.System, Float64}(c_sys5 => 340000.0,  
                                             c_sys14 => 120000.0)

    for sys in systems, p in parameters_value
        @info("Testing ED StandardPTDFForm solve")
        @testset "ED StandardPTDFForm model parameters = $(p)" begin
        ED = OperationModel(TestOptModel, model_ref, sys; PTDF = PTDF_ref[sys], optimizer = OSQP_optimizer, parameters = p)
        res = solve_op_model!(ED)
        @test termination_status(ED.canonical_model.JuMPmodel) == MOI.OPTIMAL
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], test_results[sys], atol = 10000)
        end
    end
end

@testset "Solving ED With PowerModels with loss-less convex models" begin
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [PM.DCPlosslessForm,
                PM.NFAForm]
    test_results = Dict{PSY.System, Float64}(c_sys5 => 320000.0,  
                                             c_sys14 => 140000.0)

    for  net in networks, p in parameters_value, sys in systems
        @info("Testing ED $(net) solve")
        @testset "ED model $(net) and parameters = $(p)" begin
        model_ref = ModelReference(net, devices, branches, services);
        ED = OperationModel(TestOptModel, model_ref, sys; optimizer = OSQP_optimizer, parameters = p);
        res = solve_op_model!(ED)
        #The tolerance range here is large because NFA has a much lower objective value
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], test_results[sys], atol = 25000)
        @test termination_status(ED.canonical_model.JuMPmodel) in [MOI.OPTIMAL]
        end
    end

end

@testset "Solving ED With PowerModels with loss-less convex models" begin
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [PM.StandardDCPLLForm, 
                PM.AbstractLPACCForm]
    test_results = Dict{PSY.System, Float64}(c_sys5 => 340000.0,  
                                             c_sys14 => 140000.0)

    for  net in networks, p in parameters_value, sys in systems
        @info("Testing ED $(net) solve")
        @testset "ED model $(net) and parameters = $(p)" begin
        model_ref = ModelReference(net, devices, branches, services);
        ED = OperationModel(TestOptModel, model_ref, sys; optimizer = ipopt_optimizer, parameters = p);
        res = solve_op_model!(ED)
        #The tolerance range here is large because NFA has a much lower objective value
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], test_results[sys], atol = 10000)
        @test termination_status(ED.canonical_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        end
    end

end

#= These tests are broken temporarily
@testset "Solving ED With PowerModels with convex SOC and QC models" begin
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [PM.SOCWRForm,
                 PM.QCWRForm,
                 PM.QCWRTriForm,]
    test_results = Dict{PSY.System, Float64}(c_sys5 => 340000.0,  
                                             c_sys14 => 140000.0)

    for  net in networks, p in parameters_value, sys in systems
        @info("Testing ED $(net) solve")
        @testset "ED model $(net) and parameters = $(p)" begin
        model_ref = ModelReference(net, devices, branches, services);
        ED = OperationModel(TestOptModel, model_ref, sys; optimizer = ipopt_optimizer, parameters = p);
        res = solve_op_model!(ED)
        #The tolerance range here is large because NFA has a much lower objective value
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], test_results[sys], atol = 10000)
        @test termination_status(ED.canonical_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        end
    end

end
=#


@testset "Solving ED With PowerModels Non-Convex Networks" begin
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [PM.StandardACPForm,
                PM.StandardACRForm,
                PM.StandardACTForm]
        test_results = Dict{PSY.System, Float64}(c_sys5 => 340000.0,  
                                             c_sys14 => 140000.0)

    for  net in networks, p in parameters_value, sys in systems
        @info("Testing ED $(net) solve")
        @testset "ED model $(net) and parameters = $(p)" begin
        model_ref = ModelReference(net, devices, branches, services);
        ED = OperationModel(TestOptModel, model_ref, sys; optimizer = ipopt_optimizer, parameters = p);
        res = solve_op_model!(ED)
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], test_results[sys], atol = 10000)
        @test termination_status(ED.canonical_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        end
    end

end

@testset "Solving UC Linear Networks" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalUnitCommitment),
                                        :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
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