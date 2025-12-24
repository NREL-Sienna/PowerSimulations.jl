@testset "Security Constrained branch formulation DC-PF with Virtual PTDF/LODF Model" begin
    template = get_thermal_dispatch_template_network(PTDFPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5]#, c_sys14, c_sys14_dc] #TODO Highs does not find a solution for 14 buses but Xpress does. Check why.
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        #PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
        PSI.ConstraintKey(PostContingencyEmergencyFlowRateConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(PostContingencyEmergencyFlowRateConstraint, PSY.Line, "ub"),
    ]
    PTDF_ref = IdDict{System, VirtualPTDF}(
        c_sys5 => VirtualPTDF(c_sys5),
        c_sys14 => VirtualPTDF(c_sys14),
        c_sys14_dc => VirtualPTDF(c_sys14_dc),
    )
    LODF_ref = IdDict{System, VirtualLODF}(
        c_sys5 => VirtualLODF(c_sys5),
        c_sys14 => VirtualLODF(c_sys14),
        c_sys14_dc => VirtualLODF(c_sys14_dc),
    )
    lines_outages = IdDict{System, Vector{String}}(
        c_sys5 => ["1", "2", "3"],
        c_sys14 => ["Line1", "Line2", "Line9", "Line10", "Line12", "Trans2"],
        c_sys14_dc => ["Line1", "Line9", "Line10", "Line12", "Trans2"],
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [120, 0, 696, 696, 24],
        c_sys14 => [600, 0, 3480, 3480, 504],
        c_sys14_dc => [600, 0, 2688, 2592, 456],
    )

    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 355231.0,
        c_sys14 => 141964.156,
        c_sys14_dc => 141964.156,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(
            NetworkModel(
                PTDFPowerModel;
                PTDF_matrix = PTDF_ref[sys],
                LODF_matrix = LODF_ref[sys],
            ),
        )
        set_device_model!(template, Line, SecurityConstrainedStaticBranch)
        set_device_model!(template, Transformer2W, SecurityConstrainedStaticBranch)
        set_device_model!(template, TapTransformer, SecurityConstrainedStaticBranch)
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        for branch_name in lines_outages[sys]
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            component = get_component(ACTransmission, sys, branch_name)
            add_supplemental_attribute!(sys, component, transition_data)
        end

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)

        moi_tests(
            ps_model,
            test_results[sys]...,
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.ALMOST_OPTIMAL],
            test_obj_values[sys],
            10000,
        )
    end
end

@testset "Security Constrained branch formulation Network DC-PF with PTDF/LODF Model" begin
    template = get_thermal_dispatch_template_network(PTDFPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5]#, c_sys14, c_sys14_dc] #TODO Highs does not find a solution for 14 buses but Xpress does. Check why.
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(PostContingencyEmergencyFlowRateConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(PostContingencyEmergencyFlowRateConstraint, PSY.Line, "ub"),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
        c_sys14 => PTDF(c_sys14),
        c_sys14_dc => PTDF(c_sys14_dc),
    )
    LODF_ref = IdDict{System, LODF}(
        c_sys5 => LODF(c_sys5),
        c_sys14 => LODF(c_sys14),
        c_sys14_dc => LODF(c_sys14_dc),
    )
    lines_outages = IdDict{System, Vector{String}}(
        c_sys5 => ["1", "2", "3"],
        c_sys14 => ["Line1", "Line2", "Line9", "Line10", "Line12", "Trans2"],
        c_sys14_dc => ["Line1", "Line9", "Line10", "Line12", "Trans2"],
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [120, 0, 696, 696, 24],
        c_sys14 => [600, 0, 3480, 3480, 504],
        c_sys14_dc => [600, 0, 2688, 2592, 456],
    )

    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 355231,
        c_sys14 => 141964.156,
        c_sys14_dc => 141964.156,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(
            NetworkModel(
                PTDFPowerModel;
                PTDF_matrix = PTDF_ref[sys],
                LODF_matrix = LODF_ref[sys],
            ),
        )
        set_device_model!(template, Line, SecurityConstrainedStaticBranch)
        set_device_model!(template, Transformer2W, SecurityConstrainedStaticBranch)
        set_device_model!(template, TapTransformer, SecurityConstrainedStaticBranch)

        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        for line_name in lines_outages[sys]
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            component = get_component(ACTransmission, sys, line_name)
            add_supplemental_attribute!(sys, component, transition_data)
        end

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)

        moi_tests(
            ps_model,
            test_results[sys]...,
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.ALMOST_OPTIMAL],
            test_obj_values[sys],
            10000,
        )
    end
end

@testset "Security Constrained branch formulation Network DC-PF with PTDF/LODF Model and parallel lines" begin
    template = get_thermal_dispatch_template_network(PTDFPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    l4 = get_component(Line, c_sys5, "4")
    add_equivalent_ac_transmission_with_parallel_circuits!(c_sys5, l4, PSY.Line)
    systems = [c_sys5]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(PostContingencyEmergencyFlowRateConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(PostContingencyEmergencyFlowRateConstraint, PSY.Line, "ub"),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
    )
    LODF_ref = IdDict{System, LODF}(
        c_sys5 => LODF(c_sys5),
    )
    lines_outages = IdDict{System, Vector{String}}(
        c_sys5 => ["1", "2", "3"],
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [120, 0, 696, 696, 24],
    )

    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 355231,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(
            NetworkModel(
                PTDFPowerModel;
                PTDF_matrix = PTDF_ref[sys],
                LODF_matrix = LODF_ref[sys],
            ),
        )
        set_device_model!(template, Line, SecurityConstrainedStaticBranch)
        set_device_model!(template, Transformer2W, SecurityConstrainedStaticBranch)
        set_device_model!(template, TapTransformer, SecurityConstrainedStaticBranch)

        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        for line_name in lines_outages[sys]
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            component = get_component(ACTransmission, sys, line_name)
            add_supplemental_attribute!(sys, component, transition_data)
        end

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)

        moi_tests(
            ps_model,
            test_results[sys]...,
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.ALMOST_OPTIMAL],
            test_obj_values[sys],
            10000,
        )
    end
end
