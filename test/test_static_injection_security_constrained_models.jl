#Preliminary tests for Static Injection Security Constrained Models
@testset "G-n with reserves deliverability constraints Dispatch with responding reserves only up" begin
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
