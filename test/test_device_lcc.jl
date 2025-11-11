@testset "LCC HVDC System Tests" begin
    sys5 = build_system(PSISystems, "2Area 5 Bus System")
    hvdc = first(get_components(TwoTerminalGenericHVDCLine, sys5))
    lcc = TwoTerminalLCCLine(;
        name = "lcc",
        available = true,
        arc = hvdc.arc,
        active_power_flow = 0.1,
        r = 0.000189,
        transfer_setpoint = -100.0,
        scheduled_dc_voltage = 7.5,
        rectifier_bridges = 2,
        rectifier_delay_angle_limits = (min = 0.31590, max = 1.570),
        rectifier_rc = 2.6465e-5,
        rectifier_xc = 0.001092,
        rectifier_base_voltage = 230.0,
        inverter_bridges = 2,
        inverter_extinction_angle_limits = (min = 0.3037, max = 1.57076),
        inverter_rc = 2.6465e-5,
        inverter_xc = 0.001072,
        inverter_base_voltage = 230.0,
        power_mode = true,
        switch_mode_voltage = 0.0,
        compounding_resistance = 0.0,
        min_compounding_voltage = 0.0,
        rectifier_transformer_ratio = 0.09772,
        rectifier_tap_setting = 1.0,
        rectifier_tap_limits = (min = 1, max = 1),
        rectifier_tap_step = 0.00624,
        rectifier_delay_angle = 0.31590,
        rectifier_capacitor_reactance = 0.1,
        inverter_transformer_ratio = 0.07134,
        inverter_tap_setting = 1.0,
        inverter_tap_limits = (min = 1, max = 1),
        inverter_tap_step = 0.00625,
        inverter_extinction_angle = 0.31416,
        inverter_capacitor_reactance = 0.0,
        active_power_limits_from = (min = -3.0, max = 3.0),
        active_power_limits_to = (min = -3.0, max = 3.0),
        reactive_power_limits_from = (min = -3.0, max = 3.0),
        reactive_power_limits_to = (min = -3.0, max = 3.0),
    )

    add_component!(sys5, lcc)
    remove_component!(sys5, hvdc)

    template = get_thermal_dispatch_template_network(
        NetworkModel(
            ACPPowerModel;
            use_slacks = false,
        ),
    )

    set_device_model!(template, TwoTerminalLCCLine, PSI.HVDCTwoTerminalLCC)
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)

    model = DecisionModel(
        template,
        sys5;
        optimizer = optimizer_with_attributes(Ipopt.Optimizer),
        horizon = Hour(2),
    )
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end
