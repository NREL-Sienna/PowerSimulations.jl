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
    set_device_model!(template_uc, DeviceModel(InterconnectingConverter, LossLessConverter))
    set_device_model!(template_uc, DeviceModel(TModelHVDCLine, LossLessLine))
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
    set_device_model!(template_uc, DeviceModel(InterconnectingConverter, LossLessConverter))
    set_device_model!(template_uc, DeviceModel(TModelHVDCLine, LossLessLine))
    model = DecisionModel(template_uc, sys_5; name = "UC", optimizer = HiGHS_optimizer)
    @test build!(model; output_dir = mktempdir()) == PSI.ModelBuildStatus.BUILT
    moi_tests(model, 1416, 0, 1248, 528, 672, true)
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end

@testset "HVDC with AC PF in the loop" begin
    sys = build_system(PSISystems, "RTS_GMLC_DA_sys")

    hvdc = only(get_components(TwoTerminalGenericHVDCLine, sys))
    from = get_from(get_arc(hvdc))
    to = get_to(get_arc(hvdc))

    # remove components that impact total bus power at the HVDC line buses
    components = get_components(
        x -> get_number(get_bus(x)) ∈ (get_number(from), get_number(to)),
        StaticInjection,
        sys,
    )
    for c in components
        remove_component!(sys, c)
    end
    # change reference bus to a different bus to be able to check powers at from and to buses
    set_bustype!(from, ACBusTypes.PV)
    set_bustype!(get_component(ACBus, sys, "Arthur"), ACBusTypes.REF)

    template_uc =
        ProblemTemplate(NetworkModel(PTDFPowerModel; power_flow_evaluation = ACPowerFlow()))

    set_device_model!(template_uc, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranch))
    set_device_model!(
        template_uc,
        DeviceModel(TwoTerminalGenericHVDCLine, HVDCTwoTerminalDispatch),
    )

    model = DecisionModel(template_uc, sys; name = "UC", optimizer = HiGHS_optimizer)

    @test build!(model; output_dir = mktempdir()) == PSI.ModelBuildStatus.BUILT
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    results = OptimizationProblemResults(model)
    vd = read_variables(results)
    ad = read_aux_variables(results)

    data = PSI.get_power_flow_data(
        only(PSI.get_power_flow_evaluation_data(PSI.get_optimization_container(model))),
    )
    base_power = get_base_power(sys)

    # test that the power flow results for the HVDC buses match the HVDC power transfer from the simulation
    @test isapprox(
        data.bus_activepower_injection[data.bus_lookup[get_number(from)], :] * base_power,
        vd["FlowActivePowerFromToVariable__TwoTerminalGenericHVDCLine"][:, "DC1"],
        atol = 1e-9,
        rtol = 0,
    )
    @test isapprox(
        data.bus_activepower_injection[data.bus_lookup[get_number(to)], :] * base_power,
        vd["FlowActivePowerToFromVariable__TwoTerminalGenericHVDCLine"][:, "DC1"],
        atol = 1e-9,
        rtol = 0,
    )
end
