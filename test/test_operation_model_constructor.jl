devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.StaticLine),
                                     :T => DeviceModel(PSY.Transformer2W, PSI.StaticTransformer),
                                     :TT => DeviceModel(PSY.TapTransformer , PSI.StaticTransformer))
services = Dict{Symbol, PSI.ServiceModel}()
@testset "Operation Model kwargs with CopperPlatePowerModel base" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services);
    op_problem = OperationsProblem(TestOpProblem, template,
                                            c_sys5;
                                            optimizer = GLPK_optimizer,
                                           use_parameters = true)
    moi_tests(op_problem, true, 120, 0, 120, 120, 24, false)
    op_problem = OperationsProblem(TestOpProblem, template,
                                            c_sys14;
                                            optimizer = OSQP_optimizer)
    moi_tests(op_problem, false, 120, 0, 120, 120, 24, false)
    op_problem = OperationsProblem(TestOpProblem, template,
                                            c_sys5_re;
                                            use_forecast_data = false,
                                            optimizer = GLPK_optimizer)
    moi_tests(op_problem, false, 5, 0, 5, 5, 1, false)
    op_problem = OperationsProblem(TestOpProblem, template,
                                            c_sys5_re;
                                            use_forecast_data = false,
                                            parameters = false,
                                            optimizer = GLPK_optimizer)
    moi_tests(op_problem, false, 5, 0, 5, 5, 1, false)
end


@testset "Operation Model Constructors with Parameters" begin
    networks = [PSI.CopperPlatePowerModel,
                PSI.StandardPTDFModel,
                DCPPowerModel,
                NFAPowerModel,
                ACPPowerModel,
                ACRPowerModel,
                ACTPowerModel,
                DCPLLPowerModel,
                LPACCPowerModel,
                SOCWRPowerModel,
                QCRMPowerModel,
                QCLSPowerModel];

    thermal_gens = [PSI.ThermalStandardUnitCommitment,
                    PSI.ThermalDispatch,
                    PSI.ThermalRampLimited,
                    PSI.ThermalDispatchNoMin];

        systems = [c_sys5,
                   c_sys5_re,
                   c_sys5_bat];

    for net in networks, thermal in thermal_gens, system in systems, p in [true, false]
        @testset "Operation Model $(net) - $(thermal) - $(system)" begin
            thermal_model = DeviceModel(PSY.ThermalStandard, thermal)
            devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, thermal),
                                                :Loads =>       DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
            branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.StaticLine))
            template = OperationsProblemTemplate(net, devices, branches, services);
            op_problem = OperationsProblem(TestOpProblem,
                                      template,
                                      system; PTDF = PTDF5, use_parameters = p);
        @test :nodal_balance_active in keys(op_problem.psi_container.expressions)
        @test (:params in keys(op_problem.psi_container.JuMPmodel.ext)) == p
        end


    end

end
