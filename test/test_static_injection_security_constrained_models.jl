@testset "G-n with reserves deliverability constraints Dispatch with responding reserves only up" begin
    for add_parallel_line in [true, false]
        c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
        if add_parallel_line
            l4 = get_component(Line, c_sys5, "4")
            l4_copy = Line(;
                name = PSY.get_name(l4) * "_copy",
                available = PSY.get_available(l4),
                active_power_flow = PSY.get_active_power_flow(l4),
                reactive_power_flow = PSY.get_reactive_power_flow(l4),
                arc = PSY.get_arc(l4),
                r = PSY.get_r(l4),
                x = PSY.get_x(l4),
                b = PSY.get_b(l4),
                rating = PSY.get_rating(l4),
                angle_limits = PSY.get_angle_limits(l4),
                rating_b = PSY.get_rating_b(l4),
                rating_c = PSY.get_rating_c(l4),
                g = PSY.get_g(l4),
                services = PSY.get_services(l4),
                ext = PSY.get_ext(l4))
            add_component!(c_sys5, l4_copy)
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
            ), PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
            PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
            PSI.ConstraintKey(
                RequirementConstraint,
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
            PSI.ConstraintKey(
                PostContingencyRampConstraint,
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
                reserve_up = get_component(VariableReserve{ReserveUp}, c_sys5, "Reserve1")
                add_supplemental_attribute!(sys, reserve_up, transition_data)
            end

            template = get_thermal_dispatch_template_network(
                NetworkModel(PTDFPowerModel; PTDF_matrix = PTDF_ref[sys]),
            )
            set_service_model!(template,
                ServiceModel(
                    VariableReserve{ReserveUp},
                    RangeReserveWithDeliverabilityConstraints,
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
        end
    end
end

@testset "G-n with reserves deliverability constraints UC allowing 2 reserve products to respond" begin
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
        PSI.ConstraintKey(
            PostContingencyRampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1",
        ),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [1104, 0, 1200, 600, 336],
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
            reserve_up = get_component(VariableReserve{ReserveUp}, c_sys5, "Reserve1")
            add_supplemental_attribute!(sys, reserve_up, transition_data)
            reserve_up2 = get_component(VariableReserve{ReserveUp}, c_sys5, "Reserve11")
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
                RangeReserveWithDeliverabilityConstraints,
                "Reserve1",
            ))

        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                RangeReserveWithDeliverabilityConstraints,
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

@testset "G-n with reserves deliverability constraints with AreaPTDFPowerModel" begin
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
        PSI.ConstraintKey(
            PostContingencyRampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_1",
        ),
        PSI.ConstraintKey(
            PostContingencyRampConstraint,
            PSY.VariableReserve{ReserveUp},
            "Reserve1_2",
        ),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5_2area => PTDF(c_sys5_2area),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5_2area => [1032, 0, 1392, 1200, 408],
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
                RangeReserveWithDeliverabilityConstraints,
                "Reserve1_1",
            ))
        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveUp},
                RangeReserveWithDeliverabilityConstraints,
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
    end
end
