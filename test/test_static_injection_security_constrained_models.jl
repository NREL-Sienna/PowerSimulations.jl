#Preliminar tests for Static Injection Security Constrained Models
@testset "Network DC-PF with Reserves Deliverability Constraints" begin
    template = get_thermal_dispatch_template_network(PTDFPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    systems = [c_sys5]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(
            PostContingencyEmergencyFlowRateConstraint,
            PSY.ThermalStandard,
            "lb",
        ),
        PSI.ConstraintKey(
            PostContingencyEmergencyFlowRateConstraint,
            PSY.ThermalStandard,
            "ub",
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
            PSY.VariableReserve{ReserveDown},
            "Reserve2",
        ),
        PSI.ConstraintKey(PostContingencyGenerationBalanceConstraint, PSY.ThermalStandard),
        PSI.ConstraintKey(
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            PSY.ThermalStandard,
            "up",
        ),
        PSI.ConstraintKey(
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            PSY.ThermalStandard,
            "dn",
        ),
        PSI.ConstraintKey(PostContingencyRampConstraint, PSY.ThermalStandard, "up"),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [552, 0, 720, 600, 216],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 340000.0,
    )
    for (ix, sys) in enumerate(systems)
        components_outages_names = ["Alta"]
        for component_name in components_outages_names
            # --- Create Outage Data ---
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,  # Units of hours
                outage_transition_probability = 0.9999,  # Probability for outage per hour
            )
            # --- Create Outage Data to a Line ---
            component = get_component(ThermalStandard, sys, component_name) #Brighton (Infeasible), Solitude (infinite Iteration),  Park City, Alta, Sundance
            add_supplemental_attribute!(sys, component, transition_data)
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

        set_service_model!(template,
            ServiceModel(
                VariableReserve{ReserveDown},
                RangeReserveWithDeliverabilityConstraints,
                "Reserve2",
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
    # PTDF input Error testing
    ps_model = DecisionModel(template, c_sys5; optimizer = HiGHS_optimizer)
    @test build!(
        ps_model;
        console_level = Logging.AboveMaxLevel,  # Ignore expected errors.
        output_dir = mktempdir(; cleanup = true),
    ) == PSI.ModelBuildStatus.FAILED
end
