@testset "G-n with Ramp reserve deliverability constraints Dispatch with responding reserves only up, including reduction of parallel circuits" begin
    for add_parallel_line in [true, false]
        c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
        if add_parallel_line
            l4 = get_component(Line, c_sys5, "4")
            add_parallel_ac_transmission!(c_sys5, l4, PSY.Line)
        end
        systems = [c_sys5]
        objfuncs = [GAEVF, GQEVF, GQEVF]
        constraint_keys = [
            PSI.ConstraintKey(
                ActivePowerVariableLimitsConstraint,
                PSY.ThermalStandard,
                "lb",
            ),
            PSI.ConstraintKey(
                ActivePowerVariableLimitsConstraint,
                PSY.ThermalStandard,
                "ub",
            ),
            PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
            PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
            PSI.ConstraintKey(
                PostContingencyEmergencyRateLimitConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1 -lb",
            ),
            PSI.ConstraintKey(
                PostContingencyEmergencyRateLimitConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1 -ub",
            ),
            PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
            PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
            PSI.ConstraintKey(
                RequirementConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1",
            ),
            PSI.ConstraintKey(
                RampConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1",
            ),
            PSI.ConstraintKey(
                PostContingencyGenerationBalanceConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1",
            ),
            PSI.ConstraintKey(
                PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1",
            ),
        ]
        PTDF_ref = IdDict{System, PTDF}(
            c_sys5 => PTDF(c_sys5),
        )
        test_results = IdDict{System, Vector{Int}}(
            c_sys5 => [504, 0, 600, 432, 216],
        )
        test_obj_values = IdDict{System, Float64}(
            c_sys5 => 329000.0,
        )
        components_outages_cases = IdDict{System, Vector{String}}(
            c_sys5 => ["Alta"],
        )
        for (ix, sys) in enumerate(systems)
            gen = get_component(ThermalStandard, sys, "Solitude")
            set_ramp_limits!(gen, (up = 0.4, down = 0.4)) #Increase ramp limits to make the problem feasible
            components_outages_names = components_outages_cases[sys]
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, "Reserve1")
            for component_name in components_outages_names
                # --- Create Outage Data ---
                transition_data = GeometricDistributionForcedOutage(;
                    mean_time_to_recovery = 10,
                    outage_transition_probability = 0.9999,
                )
                # --- Add Outage Supplemental attribute to device and services that should respond ---
                component = get_component(ThermalStandard, sys, component_name)
                add_supplemental_attribute!(sys, component, transition_data)
                add_supplemental_attribute!(sys, reserve_up, transition_data)
            end
            template = get_thermal_dispatch_template_network(
                NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF_ref[sys]),
            )
            set_service_model!(template,
                ServiceModel(
                    VariableReserve{ReserveUp},
                    RampReserveWithDeliverabilityConstraints,
                    "Reserve1",
                ))

            ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

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
            res = OptimizationProblemResults(ps_model)
            compare_outage_power_and_deployed_reserves(
                sys,
                res,
                reserve_up)
        end
    end
end

@testset "G-n with contingency reserves deliverability constraints including responding reserves only up, reserve requirement, and reduction of parallel circuits" begin
    for add_parallel_line in [true, false]
        c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)

        if add_parallel_line
            l4 = get_component(Line, c_sys5, "4")
            add_parallel_ac_transmission!(c_sys5, l4, PSY.Line)
        end
        systems = [c_sys5]
        objfuncs = [GAEVF, GQEVF, GQEVF]
        constraint_keys = [
            PSI.ConstraintKey(
                ActivePowerVariableLimitsConstraint,
                PSY.ThermalStandard,
                "lb",
            ),
            PSI.ConstraintKey(
                ActivePowerVariableLimitsConstraint,
                PSY.ThermalStandard,
                "ub",
            ),
            PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
            PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
            PSI.ConstraintKey(
                PostContingencyEmergencyRateLimitConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1 -lb",
            ),
            PSI.ConstraintKey(
                PostContingencyEmergencyRateLimitConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1 -ub",
            ),
            PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
            PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
            PSI.ConstraintKey(
                RequirementConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1",
            ),
            PSI.ConstraintKey(
                RampConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1",
            ),
            PSI.ConstraintKey(
                PostContingencyGenerationBalanceConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1",
            ),
            PSI.ConstraintKey(
                PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1",
            ),
        ]
        PTDF_ref = IdDict{System, PTDF}(
            c_sys5 => PTDF(c_sys5),
        )
        test_results = IdDict{System, Vector{Int}}(
            c_sys5 => [504, 0, 600, 432, 216],
        )
        test_obj_values = IdDict{System, Float64}(
            c_sys5 => 329000.0,
        )
        components_outages_cases = IdDict{System, Vector{String}}(
            c_sys5 => ["Alta"],
        )
        for (ix, sys) in enumerate(systems)
            gen = get_component(ThermalStandard, sys, "Solitude")
            set_ramp_limits!(gen, (up = 0.4, down = 0.4)) #Increase ramp limits to make the problem feasible
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, "Reserve1")

            components_outages_names = components_outages_cases[sys]
            for component_name in components_outages_names
                # --- Create Outage Data ---
                transition_data = GeometricDistributionForcedOutage(;
                    mean_time_to_recovery = 10,
                    outage_transition_probability = 0.9999,
                )
                # --- Add Outage Supplemental attribute to device and services that should respond ---
                component = get_component(ThermalStandard, sys, component_name)
                add_supplemental_attribute!(sys, component, transition_data)
                add_supplemental_attribute!(sys, reserve_up, transition_data)
            end
            template = get_thermal_dispatch_template_network(
                NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF_ref[sys]),
            )
            set_service_model!(template,
                ServiceModel(
                    VariableReserve{ReserveUp},
                    ContingencyReserveWithDeliverabilityConstraints,
                    "Reserve1",
                ))

            ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

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
            res = OptimizationProblemResults(ps_model)
            compare_outage_power_and_deployed_reserves(
                sys,
                res,
                reserve_up)
        end
    end
end

@testset "G-n with contingency reserves deliverability constraints including responding reserves only up, NO reserve requirement, and reduction of parallel circuits" begin
    for add_parallel_line in [true, false]
        c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)

        if add_parallel_line
            l4 = get_component(Line, c_sys5, "4")
            add_parallel_ac_transmission!(c_sys5, l4, PSY.Line)
        end
        systems = [c_sys5]
        objfuncs = [GAEVF, GQEVF, GQEVF]
        constraint_keys = [
            PSI.ConstraintKey(
                ActivePowerVariableLimitsConstraint,
                PSY.ThermalStandard,
                "lb",
            ),
            PSI.ConstraintKey(
                ActivePowerVariableLimitsConstraint,
                PSY.ThermalStandard,
                "ub",
            ),
            PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
            PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
            PSI.ConstraintKey(
                PostContingencyEmergencyRateLimitConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1 -lb",
            ),
            PSI.ConstraintKey(
                PostContingencyEmergencyRateLimitConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1 -ub",
            ),
            PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
            PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
            PSI.ConstraintKey(
                PostContingencyGenerationBalanceConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1",
            ),
            PSI.ConstraintKey(
                PostContingencyActivePowerGenerationLimitsConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1 -lb",
            ),
            PSI.ConstraintKey(
                PostContingencyActivePowerGenerationLimitsConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1 -ub",
            ),
        ]
        PTDF_ref = IdDict{System, PTDF}(
            c_sys5 => PTDF(c_sys5),
        )
        test_results = IdDict{System, Vector{Int}}(
            c_sys5 => [384, 0, 504, 504, 240],
        )
        test_obj_values = IdDict{System, Float64}(
            c_sys5 => 329000.0,
        )
        components_outages_cases = IdDict{System, Vector{String}}(
            c_sys5 => ["Alta"],
        )
        for (ix, sys) in enumerate(systems)
            gen = get_component(ThermalStandard, sys, "Solitude")
            set_ramp_limits!(gen, (up = 0.4, down = 0.4)) #Increase ramp limits to make the problem feasible
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, "Reserve1")
            remove_time_series!(
                sys,
                Deterministic,
                reserve_up,
                "requirement",
            )
            components_outages_names = components_outages_cases[sys]
            for component_name in components_outages_names
                # --- Create Outage Data ---
                transition_data = GeometricDistributionForcedOutage(;
                    mean_time_to_recovery = 10,
                    outage_transition_probability = 0.9999,
                )
                # --- Add Outage Supplemental attribute to device and services that should respond ---
                component = get_component(ThermalStandard, sys, component_name)
                add_supplemental_attribute!(sys, component, transition_data)
                add_supplemental_attribute!(sys, reserve_up, transition_data)
            end
            template = get_thermal_dispatch_template_network(
                NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF_ref[sys]),
            )
            set_service_model!(template,
                ServiceModel(
                    VariableReserve{ReserveUp},
                    ContingencyReserveWithDeliverabilityConstraints,
                    "Reserve1",
                ))

            ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

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
            res = OptimizationProblemResults(ps_model)
            compare_outage_power_and_deployed_reserves(
                sys,
                res,
                reserve_up)
        end
    end
end

@testset "Test if G-n with Ramp reserve deliverability constraints builds when there is a device without set_device_model!()" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)

    l4 = get_component(Line, c_sys5, "4")
    add_parallel_ac_transmission!(c_sys5, l4, PSY.Line, PSY.MonitoredLine)
    remove_component!(c_sys5, l4)

    systems = [c_sys5]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(
            ActivePowerVariableLimitsConstraint,
            PSY.ThermalStandard,
            "lb",
        ),
        PSI.ConstraintKey(
            ActivePowerVariableLimitsConstraint,
            PSY.ThermalStandard,
            "ub",
        ),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1 -lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1 -ub",
        ),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
        PSI.ConstraintKey(
            RequirementConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1",
        ),
        PSI.ConstraintKey(
            RampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1",
        ),
        PSI.ConstraintKey(
            PostContingencyGenerationBalanceConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1",
        ),
        PSI.ConstraintKey(
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1",
        ),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [504, 0, 552, 432, 192],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 329000.0,
    )
    components_outages_cases = IdDict{System, Vector{String}}(
        c_sys5 => ["Alta"],
    )
    for (ix, sys) in enumerate(systems)
        components_outages_names = components_outages_cases[sys]
        for component_name in components_outages_names
            # --- Create Outage Data ---
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            # --- Add Outage Supplemental attribute to device and services that should respond ---
            component = get_component(ThermalStandard, sys, component_name)
            add_supplemental_attribute!(sys, component, transition_data)
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, "Reserve1")
            add_supplemental_attribute!(sys, reserve_up, transition_data)
        end

        template =
            ProblemTemplate(NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF_ref[sys]))
        set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
        set_device_model!(template, PowerLoad, StaticPowerLoad)
        #set_device_model!(template, MonitoredLine, StaticBranchBounds)
        set_device_model!(template, Line, StaticBranch)
        set_device_model!(template, Transformer2W, StaticBranch)
        set_device_model!(template, TapTransformer, StaticBranch)
        set_device_model!(template, TwoTerminalGenericHVDCLine, HVDCTwoTerminalLossless)

        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                RampReserveWithDeliverabilityConstraints,
                "Reserve1",
            ))

        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT
    end
end

@testset "G-n with Ramp reserve deliverability constraints UC allowing 2 reserve products to respond" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    systems = [c_sys5]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.ThermalStandard, "lb"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.ThermalStandard, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1 -lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1 -ub",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve11 -lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve11 -ub",
        ),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
        PSI.ConstraintKey(
            RequirementConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1",
        ),
        PSI.ConstraintKey(
            RequirementConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve11",
        ),
        PSI.ConstraintKey(
            RampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1",
        ),
        PSI.ConstraintKey(
            RampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve11",
        ),
        PSI.ConstraintKey(
            PostContingencyGenerationBalanceConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1",
        ),
        PSI.ConstraintKey(
            PostContingencyGenerationBalanceConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve11",
        ),
        PSI.ConstraintKey(
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1",
        ),
        PSI.ConstraintKey(
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve11",
        ),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [1104, 0, 1296, 600, 384],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 254242.0,
    )
    components_outages_cases = IdDict{System, Vector{String}}(
        c_sys5 => ["Alta"],
    )
    for (ix, sys) in enumerate(systems)
        components_outages_names = components_outages_cases[sys]
        for component_name in components_outages_names
            # --- Create Outage Data ---
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            # --- Add Outage Supplemental attribute to device and services that should respond ---
            component = get_component(ThermalStandard, sys, component_name)
            add_supplemental_attribute!(sys, component, transition_data)
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, "Reserve1")
            add_supplemental_attribute!(sys, reserve_up, transition_data)
            reserve_up2 = get_component(VariableReserve{ReserveUp}, sys, "Reserve11")
            add_supplemental_attribute!(sys, reserve_up2, transition_data)
        end

        template = get_thermal_dispatch_template_network(
            NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF_ref[sys]),
        )

        set_device_model!(
            template,
            ThermalStandard,
            ThermalStandardUnitCommitment,
        )

        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                RampReserveWithDeliverabilityConstraints,
                "Reserve1",
            ))

        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                RampReserveWithDeliverabilityConstraints,
                "Reserve11",
            ))

        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)
        moi_tests(
            ps_model,
            test_results[sys]...,
            true,
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

@testset "G-n with Ramp reserve deliverability constraints with AreaPTDFPowerModel" begin
    c_sys5_2area = PSB.build_system(PSISystems, "two_area_pjm_DA"; add_reserves = true)
    transform_single_time_series!(c_sys5_2area, Hour(24), Hour(1))
    systems = [c_sys5_2area]
    objfuncs = [GAEVF]
    constraint_keys = [
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.ThermalStandard, "lb"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.ThermalStandard, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1 -lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2 -lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1 -ub",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2 -ub",
        ),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.Area),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
        PSI.ConstraintKey(
            RequirementConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            RequirementConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
        PSI.ConstraintKey(
            RampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            RampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
        PSI.ConstraintKey(
            PostContingencyGenerationBalanceConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            PostContingencyGenerationBalanceConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
        PSI.ConstraintKey(
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5_2area => PTDF(c_sys5_2area),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5_2area => [1032, 0, 1536, 1200, 456],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5_2area => 497000.0,
    )
    components_outages_cases = IdDict{System, Tuple{Vector{String}, Vector{String}}}(
        c_sys5_2area => (["Alta_1", "Alta_2"], ["Reserve1_1", "Reserve1_2"]),
    )
    for (ix, sys) in enumerate(systems)
        components_outages_names, reserve_names = components_outages_cases[sys]
        for (component_name, reserve_name) in zip(components_outages_names, reserve_names)
            # --- Create Outage Data ---
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            # --- Add Outage Supplemental attribute to device and services that should respond ---
            component = get_component(ThermalStandard, sys, component_name)
            add_supplemental_attribute!(sys, component, transition_data)
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, reserve_name)
            add_supplemental_attribute!(sys, reserve_up, transition_data)
        end

        template = get_thermal_dispatch_template_network(
            NetworkModel(AreaPTDFPowerModel; PTDF_matrix = PTDF_ref[sys]),
        )
        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                RampReserveWithDeliverabilityConstraints,
                "Reserve1_1",
            ))
        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                RampReserveWithDeliverabilityConstraints,
                "Reserve1_2",
            ))
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

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
        res = OptimizationProblemResults(ps_model)
        for reserve_name in reserve_names
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, reserve_name)
            compare_outage_power_and_deployed_reserves(
                sys,
                res,
                reserve_up)
        end
    end
end


@testset "G-n with Contingency reserve deliverability constraints with AreaPTDFPowerModel, reserves only up, reserve requirement" begin
    c_sys5_2area = PSB.build_system(PSISystems, "two_area_pjm_DA"; add_reserves = true)
    transform_single_time_series!(c_sys5_2area, Hour(24), Hour(1))
    systems = [c_sys5_2area]
    objfuncs = [GAEVF]
    constraint_keys = [
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.ThermalStandard, "lb"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.ThermalStandard, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1 -lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2 -lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1 -ub",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2 -ub",
        ),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.Area),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
        PSI.ConstraintKey(
            RequirementConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            RequirementConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
        PSI.ConstraintKey(
            RampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            RampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
        PSI.ConstraintKey(
            PostContingencyGenerationBalanceConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            PostContingencyGenerationBalanceConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
        PSI.ConstraintKey(
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5_2area => PTDF(c_sys5_2area),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5_2area => [1032, 0, 1536, 1200, 456],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5_2area => 497000.0,
    )
    components_outages_cases = IdDict{System, Tuple{Vector{String}, Vector{String}}}(
        c_sys5_2area => (["Alta_1", "Alta_2"], ["Reserve1_1", "Reserve1_2"]),
    )
    for (ix, sys) in enumerate(systems)
        components_outages_names, reserve_names = components_outages_cases[sys]
        for (component_name, reserve_name) in zip(components_outages_names, reserve_names)
            # --- Create Outage Data ---
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            # --- Add Outage Supplemental attribute to device and services that should respond ---
            component = get_component(ThermalStandard, sys, component_name)
            add_supplemental_attribute!(sys, component, transition_data)
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, reserve_name)
            add_supplemental_attribute!(sys, reserve_up, transition_data)
        end

        template = get_thermal_dispatch_template_network(
            NetworkModel(AreaPTDFPowerModel; PTDF_matrix = PTDF_ref[sys]),
        )
        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                ContingencyReserveWithDeliverabilityConstraints,
                "Reserve1_1",
            ))
        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                ContingencyReserveWithDeliverabilityConstraints,
                "Reserve1_2",
            ))
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

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
        res = OptimizationProblemResults(ps_model)
        for reserve_name in reserve_names
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, reserve_name)
            compare_outage_power_and_deployed_reserves(
                sys,
                res,
                reserve_up)
        end
    end
end

@testset "G-n with Contingency reserve deliverability constraints with AreaPTDFPowerModel, reserves only up, NO reserve requirement" begin
    c_sys5_2area = PSB.build_system(PSISystems, "two_area_pjm_DA")
    transform_single_time_series!(c_sys5_2area, Hour(24), Hour(1))
    systems = [c_sys5_2area]
    objfuncs = [GAEVF]
    constraint_keys = [
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.ThermalStandard, "lb"),
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, PSY.ThermalStandard, "ub"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1 -lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2 -lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1 -ub",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyRateLimitConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2 -ub",
        ),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.Area),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),

        PSI.ConstraintKey(
            PostContingencyGenerationBalanceConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            PostContingencyGenerationBalanceConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
        
        PSI.ConstraintKey(
                PostContingencyActivePowerGenerationLimitsConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1_1 -lb",
            ),
        PSI.ConstraintKey(
                PostContingencyActivePowerGenerationLimitsConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1_1 -ub",
        ),
        PSI.ConstraintKey(
                PostContingencyActivePowerGenerationLimitsConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1_2 -lb",
            ),
        PSI.ConstraintKey(
                PostContingencyActivePowerGenerationLimitsConstraint,
                PSY.VariableReserve{ReserveUp},
                "Reserve1_2 -ub",
        ),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5_2area => PTDF(c_sys5_2area),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5_2area => [792, 0, 1344, 1344, 504],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5_2area => 497000.0,
    )
    components_outages_cases = IdDict{System, Tuple{Vector{String}, Vector{String}}}(
        c_sys5_2area => (["Alta_1", "Alta_2"], ["Reserve1_1", "Reserve1_2"]),
    )
    for (ix, sys) in enumerate(systems)
        components_outages_names, reserve_names = components_outages_cases[sys]
        contributing_devices = get_components(g -> get_name(get_area(get_bus(g))) == "Area1", ThermalStandard, sys)
        add_reserve_product_without_requirement_time_series!(sys, "Reserve1_1", "Up", contributing_devices)
        contributing_devices = get_components(g -> get_name(get_area(get_bus(g))) == "Area2", ThermalStandard, sys)
        add_reserve_product_without_requirement_time_series!(sys, "Reserve1_2", "Up", contributing_devices)
        
        for (component_name, reserve_name) in zip(components_outages_names, reserve_names)
            # --- Create Outage Data ---
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            # --- Add Outage Supplemental attribute to device and services that should respond ---
            component = get_component(ThermalStandard, sys, component_name)
            add_supplemental_attribute!(sys, component, transition_data)
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, reserve_name)
            add_supplemental_attribute!(sys, reserve_up, transition_data)
        end

        template = get_thermal_dispatch_template_network(
            NetworkModel(AreaPTDFPowerModel; PTDF_matrix = PTDF_ref[sys]),
        )
        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                ContingencyReserveWithDeliverabilityConstraints,
                "Reserve1_1",
            ))
        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                ContingencyReserveWithDeliverabilityConstraints,
                "Reserve1_2",
            ))
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

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
        res = OptimizationProblemResults(ps_model)
        for reserve_name in reserve_names
            reserve_up = get_component(VariableReserve{ReserveUp}, sys, reserve_name)
            compare_outage_power_and_deployed_reserves(
                sys,
                res,
                reserve_up)
        end
    end
end

@testset "G-1 (Thermal Formulation) with deliverability constraints including reduction of parallel circuits" begin
    for add_parallel_line in [true, false]
        c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc")
        if add_parallel_line
            l4 = get_component(Line, c_sys5, "4")
            add_parallel_ac_transmission!(c_sys5, l4, PSY.Line)
        end
        systems = [c_sys5]
        objfuncs = [GAEVF, GQEVF, GQEVF]
        constraint_keys = [
            PSI.ConstraintKey(
                ActivePowerVariableLimitsConstraint,
                PSY.ThermalStandard,
                "lb",
            ),
            PSI.ConstraintKey(
                ActivePowerVariableLimitsConstraint,
                PSY.ThermalStandard,
                "ub",
            ),
            PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
            PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
            PSI.ConstraintKey(
                PostContingencyEmergencyRateLimitConstraint,
                ThermalStandard,
                "lb",
            ),
            PSI.ConstraintKey(
                PostContingencyEmergencyRateLimitConstraint,
                ThermalStandard,
                "ub",
            ),
            #PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
            PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
            PSI.ConstraintKey(
                PostContingencyGenerationBalanceConstraint,
                ThermalStandard,
            ),
            PSI.ConstraintKey(
                PostContingencyActivePowerGenerationLimitsConstraint,
                ThermalStandard,
                "lb",
            ),
            PSI.ConstraintKey(
                PostContingencyActivePowerGenerationLimitsConstraint,
                ThermalStandard,
                "ub",
            ),
            PSI.ConstraintKey(
                PostContingencyRampConstraint,
                ThermalStandard,
                "",
            ),
        ]
        PTDF_ref = IdDict{System, PTDF}(
            c_sys5 => PTDF(c_sys5),
        )
        test_results = IdDict{System, Vector{Int}}(
            c_sys5 => [744, 0, 912, 504, 360],
        )
        test_obj_values = IdDict{System, Float64}(
            c_sys5 => 263507.0,
        )
        components_outages_cases = IdDict{System, Vector{String}}(
            c_sys5 => ["Alta"],
        )
        for (ix, sys) in enumerate(systems)
            components_outages_names = components_outages_cases[sys]
            for component_name in components_outages_names
                # --- Create Outage Data ---
                transition_data = GeometricDistributionForcedOutage(;
                    mean_time_to_recovery = 10,
                    outage_transition_probability = 0.9999,
                )
                # --- Add Outage Supplemental attribute to device and services that should respond ---
                component = get_component(ThermalStandard, sys, component_name)
                add_supplemental_attribute!(sys, component, transition_data)
            end
            template = get_thermal_dispatch_template_network(
                NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF_ref[sys]),
            )
            set_device_model!(
                template,
                ThermalStandard,
                ThermalSecurityConstrainedStandardUnitCommitment,
            )

            ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

            @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
                  PSI.ModelBuildStatus.BUILT
            psi_constraint_test(ps_model, constraint_keys)
            moi_tests(
                ps_model,
                test_results[sys]...,
                true,
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
end
