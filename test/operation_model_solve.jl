devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.StaticLine),
                                     :T => DeviceModel(PSY.Transformer2W, PSI.StaticTransformer),
                                     :TT => DeviceModel(PSY.TapTransformer , PSI.StaticTransformer))
services = Dict{Symbol, PSI.ServiceModel}()

@testset "Solving ED with CopperPlate" begin
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    parameters_value = [true, false]
    systems = [c_sys5, c_sys14]
    test_results = Dict{PSY.System, Float64}(c_sys5 => 240000.0,  
                                             c_sys14 => 142000.0)
    for sys in systems, p in parameters_value
        @info("Testing solve ED with CopperPlatePowerModel network")
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
    systems = [c_sys5, c_sys14, c_sys14_dc]
    PTDF_ref = Dict{PSY.System, PSY.PTDF}(c_sys5 => PTDF5, c_sys14 => PTDF14, c_sys14_dc => PTDF14_dc)
    test_results = Dict{PSY.System, Float64}(c_sys5 => 340000.0,  
                                             c_sys14 => 142000.0,
                                             c_sys14_dc => 142000.0)

    for sys in systems, p in parameters_value
        @info("Testing solve ED with StandardPTDFForm network")
        @testset "ED StandardPTDFForm model parameters = $(p)" begin
        ED = OperationModel(TestOptModel, model_ref, sys; PTDF = PTDF_ref[sys], optimizer = OSQP_optimizer, parameters = p)
        res = solve_op_model!(ED)
        @test termination_status(ED.canonical_model.JuMPmodel) == MOI.OPTIMAL
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], test_results[sys], atol = 10000)
        end
    end
end

@testset "Solving ED With PowerModels with loss-less convex models" begin
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters_value = [true, false]
    networks = [PM.DCPlosslessForm,
                PM.NFAForm]
    test_results = Dict{PSY.System, Float64}(c_sys5 => 330000.0,  
                                             c_sys14 => 142000.0,
                                             c_sys14_dc => 142000.0)

    for  net in networks, p in parameters_value, sys in systems
        @info("Testing solve ED with $(net) network")
        @testset "ED model $(net) and parameters = $(p)" begin
        model_ref = ModelReference(net, devices, branches, services);
        ED = OperationModel(TestOptModel, model_ref, sys; optimizer = ipopt_optimizer, parameters = p);
        res = solve_op_model!(ED)
        #The tolerance range here is large because NFA has a much lower objective value
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], test_results[sys], atol = 35000)
        @test termination_status(ED.canonical_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        end
    end

end

@testset "Solving ED With PowerModels with linear convex models" begin
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [PM.StandardDCPLLForm, 
                PM.AbstractLPACCForm]
    test_results = Dict{PSY.System, Float64}(c_sys5 => 340000.0,  
                                             c_sys14 => 142000.0,
                                             c_sys14_dc => 142000.0)

    for  net in networks, p in parameters_value, sys in systems
        @info("Testing solve ED with $(net) network")
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

#=
@testset "Solving ED With PowerModels with convex SOC and QC models" begin
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [PM.SOCWRForm,
                 PM.QCWRForm,
                 PM.QCWRTriForm,]
    test_results = Dict{PSY.System, Float64}(c_sys5 => 320000.0,  
                                             c_sys14 => 142000.0)

    for  net in networks, p in parameters_value, sys in systems
        @info("Testing solve ED with $(net) network")
        @testset "ED model $(net) and parameters = $(p)" begin
        model_ref = ModelReference(net, devices, branches, services);
        ED = OperationModel(TestOptModel, model_ref, sys; optimizer = ipopt_optimizer, parameters = p);
        res = solve_op_model!(ED)
        #The tolerance range here is large because Relaxations have a lower objective value
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], test_results[sys], atol = 25000)
        @test termination_status(ED.canonical_model.JuMPmodel) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        end
    end

end
=#

@testset "Solving ED With PowerModels Non-Convex Networks" begin
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters_value = [true, false]
    networks = [PM.StandardACPForm,
                #PM.StandardACRForm,
                PM.StandardACTForm]
    test_results = Dict{PSY.System, Float64}(c_sys5 => 340000.0,  
                                             c_sys14 => 142000.0,
                                             c_sys14_dc => 142000.0)

    for  net in networks, p in parameters_value, sys in systems
        @info("Testing solve ED with $(net) network")
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
    systems = [c_sys5, c_sys5_dc]
    networks = [PM.DCPlosslessForm,
                PM.NFAForm,
                StandardPTDFForm,
                CopperPlatePowerModel]
    PTDF_ref = Dict{PSY.System, PSY.PTDF}(c_sys5 => PTDF5, c_sys5_dc => PTDF5_dc)            

    for  net in networks, p in parameters_value, sys in systems
        @info("Testing solve UC with $(net) network")
        @testset "UC model $(net) and parameters = $(p)" begin
        model_ref= ModelReference(net, devices, branches, services);
        UC = OperationModel(TestOptModel, model_ref, sys; PTDF = PTDF_ref[sys], optimizer = GLPK_optimizer, parameters = p)
        res = solve_op_model!(UC)
        @test termination_status(UC.canonical_model.JuMPmodel) == MOI.OPTIMAL
        @test isapprox(res.total_cost[:OBJECTIVE_FUNCTION], 340000, atol = 100000)
        end
    end

end
