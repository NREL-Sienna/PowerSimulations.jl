@testset "HVDC System Tests" begin
    sys_5 = build_system(PSISystems, "sys10_pjm_ac_dc")
    template_uc = ProblemTemplate(NetworkModel(
        DCPPowerModel,
        #use_slacks=true,
        #PTDF_matrix=PTDF(sys_5),
        #duals=[CopperPlateBalanceConstraint],
    ))

    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranch))
    set_device_model!(template_uc, DeviceModel(InterconnectingConverter, LosslessConverter))
    set_device_model!(template_uc, DeviceModel(TModelHVDCLine, LosslessLine))
    set_hvdc_network_model!(template_uc, TransportHVDCNetworkModel)
    model = DecisionModel(template_uc, sys_5; name = "UC", optimizer = HiGHS_optimizer)
    @test build!(model; output_dir = mktempdir()) == PSI.ModelBuildStatus.BUILT
    moi_tests(model, 1656, 288, 1248, 528, 888, true)
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    template_uc = ProblemTemplate(NetworkModel(
        PTDFPowerModel;
        #use_slacks=true,
        PTDF_matrix = PTDF(sys_5),
        #duals=[CopperPlateBalanceConstraint],
    ))

    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranch))
    set_device_model!(template_uc, DeviceModel(InterconnectingConverter, LosslessConverter))
    set_device_model!(template_uc, DeviceModel(TModelHVDCLine, LosslessLine))
    set_hvdc_network_model!(template_uc, TransportHVDCNetworkModel)
    model = DecisionModel(template_uc, sys_5; name = "UC", optimizer = HiGHS_optimizer)
    @test build!(model; output_dir = mktempdir()) == PSI.ModelBuildStatus.BUILT
    moi_tests(model, 1128, 0, 1248, 528, 384, true)
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end

function _generate_test_hvdc_sys()
    sys = build_system(PSISystems, "sys10_pjm_ac_dc"; force_build = true)
    th_names_2 = ["Alta-2", "Sundance-2", "Park City-2", "Solitude-2", "Brighton-2"]
    for th_name in th_names_2
        g = PSY.get_component(PSY.ThermalStandard, sys, th_name)
        op_cost = g.operation_cost
        val_curve = op_cost.variable.value_curve
        new_prop_term = get_proportional_term(val_curve) * 2.0
        if g.name == "Park City-2"
            new_prop_term = new_prop_term + 5.0
        end
        new_quad_cost = QuadraticCurve(
            get_quadratic_term(val_curve),
            new_prop_term,
            get_constant_term(val_curve),
        )
        new_op_cost = ThermalGenerationCost(
            CostCurve(
                new_quad_cost,
                op_cost.variable.power_units,
                op_cost.variable.vom_cost,
            ),
            op_cost.fixed,
            op_cost.start_up,
            op_cost.shut_down,
        )
        set_operation_cost!(g, new_op_cost)
    end

    for ipc in get_components(InterconnectingConverter, sys)
        new_dc_loss = QuadraticCurve(0.01, 0.01, 0.0)
        set_loss_function!(ipc, new_dc_loss)
        set_max_dc_current!(ipc, 2.0)
    end
    return sys
end

@testset "HVDC System with Transport Network" begin
    sys = _generate_test_hvdc_sys()
    template = ProblemTemplate()
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, TModelHVDCLine, LosslessLine)
    set_device_model!(template, InterconnectingConverter, LosslessConverter)
    set_hvdc_network_model!(template, TransportHVDCNetworkModel)
    model =
        DecisionModel(
            template,
            sys;
            store_variable_names = true,
            optimizer = HiGHS_optimizer,
        )
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end

@testset "HVDC System with Losses Network" begin
    sys = _generate_test_hvdc_sys()
    template = ProblemTemplate()
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, TModelHVDCLine, DCLossyLine)
    ipc_model = DeviceModel(
        InterconnectingConverter,
        QuadraticLossConverter;
        attributes = Dict(
            "voltage_segments" => 3,
            "current_segments" => 3,
            "bilinear_segments" => 3,
            "use_linear_loss" => true,
        ),
    )
    set_device_model!(template, ipc_model)
    set_hvdc_network_model!(template, VoltageDispatchHVDCNetworkModel)
    model =
        DecisionModel(
            template,
            sys;
            store_variable_names = true,
            optimizer = HiGHS_optimizer,
        )
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end
