@testset "Decision Model test for Initialization with RTS GMLC system, Case 1" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, HydroDispatch, HydroDispatchRunOfRiver)

    sys_rts = PSB.build_system(PSITestSystems, "modified_RTS_GMLC_DA_sys")
    for init_time in
        DateTime("2020-01-01T00:00:00"):Month(1):DateTime("2020-12-31T00:00:00"),
        horizon in [24, 48]

        @info(
            "Decision Model initial_conditions test with RTS-GMLC for $init_time and horizon $horizon"
        )
        model = DecisionModel(
            template,
            sys_rts;
            optimizer = SCIP_optimizer,
            initial_time = init_time,
            horizon = horizon,
        )
        @time build!(model; output_dir = mktempdir(cleanup = true)) == BuildStatus.BUILT

        ####### Check initialization problem
        check_initialization_variable_count(model, ActivePowerVariable(), ThermalStandard)
        check_initialization_variable_count(model, OnVariable(), ThermalStandard)
        check_initialization_variable_count(model, StopVariable(), ThermalStandard)
        check_initialization_variable_count(model, StartVariable(), ThermalStandard)
        check_initialization_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_initialization_variable_count(model, ActivePowerVariable(), HydroDispatch)
        ####### Check initial condition from initialization step
        check_duration_on_initial_conditions_values(model, ThermalStandard)
        check_duration_off_initial_conditions_values(model, ThermalStandard)
        check_active_power_initial_condition_values(model, ThermalStandard)
        check_status_initial_conditions_values(model, ThermalStandard)
        ####### Check variables
        check_variable_count(model, ActivePowerVariable(), ThermalStandard)
        check_variable_count(model, StopVariable(), ThermalStandard)
        check_variable_count(model, OnVariable(), ThermalStandard)
        check_variable_count(model, StartVariable(), ThermalStandard)
        check_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_variable_count(model, ActivePowerVariable(), HydroDispatch)
        ####### Check constraints 
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "lb",
        )
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "ub",
        )
        check_constraint_count(model, DurationConstraint(), ThermalStandard)
        check_constraint_count(model, RampConstraint(), ThermalStandard)
        check_constraint_count(model, CommitmentConstraint(), ThermalStandard)
        check_constraint_count(model, CommitmentConstraint(), ThermalStandard; meta = "aux")
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )

        # @time solve!(model) == RunStatus.SUCCESSFUL
    end
end

@testset "Decision Model test for Initialization with RTS GMLC system, Case 2" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, HydroDispatch, HydroCommitmentRunOfRiver)

    sys_rts = PSB.build_system(PSITestSystems, "modified_RTS_GMLC_DA_sys")
    for init_time in
        DateTime("2020-01-01T00:00:00"):Month(1):DateTime("2020-12-31T00:00:00"),
        horizon in [24, 48]

        @info(
            "Decision Model initial_conditions test with RTS-GMLC for $init_time and horizon $horizon"
        )
        model = DecisionModel(
            template,
            sys_rts;
            optimizer = SCIP_optimizer,
            initial_time = init_time,
            horizon = horizon,
        )
        @test build!(model; output_dir = mktempdir(cleanup = true)) == BuildStatus.BUILT

        ####### Check initialization problem
        check_initialization_variable_count(model, ActivePowerVariable(), ThermalStandard)
        check_initialization_variable_count(model, OnVariable(), ThermalStandard)
        check_initialization_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_initialization_variable_count(model, ActivePowerVariable(), HydroDispatch)
        ####### Check initial condition from initialization step
        check_status_initial_conditions_values(model, ThermalStandard)

        ####### Check variables
        check_variable_count(model, ActivePowerVariable(), ThermalStandard)
        check_variable_count(model, StopVariable(), ThermalStandard)
        check_variable_count(model, OnVariable(), ThermalStandard)
        check_variable_count(model, StartVariable(), ThermalStandard)
        check_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_variable_count(model, ActivePowerVariable(), HydroDispatch)
        check_variable_count(model, OnVariable(), HydroDispatch)
        ####### Check constraints 
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "lb",
        )
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "ub",
        )
        check_constraint_count(model, CommitmentConstraint(), ThermalStandard)
        check_constraint_count(model, CommitmentConstraint(), ThermalStandard; meta = "aux")

        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "lb",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )

        # @test solve!(model) == RunStatus.SUCCESSFUL
    end
end

@testset "Decision Model test for Initialization with RTS GMLC system, Case 3" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, HydroDispatch, HydroCommitmentRunOfRiver)

    sys_rts = PSB.build_system(PSITestSystems, "modified_RTS_GMLC_DA_sys")
    for init_time in
        DateTime("2020-01-01T00:00:00"):Month(1):DateTime("2020-12-31T00:00:00"),
        horizon in [24, 48]

        @info(
            "Decision Model initial_conditions test with RTS-GMLC for $init_time and horizon $horizon"
        )
        model = DecisionModel(
            template,
            sys_rts;
            optimizer = SCIP_optimizer,
            initial_time = init_time,
            horizon = horizon,
        )
        @test build!(model; output_dir = mktempdir(cleanup = true)) == BuildStatus.BUILT

        ####### Check initialization problem
        check_initialization_variable_count(model, ActivePowerVariable(), ThermalStandard)
        check_initialization_variable_count(model, OnVariable(), ThermalStandard)
        check_initialization_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_initialization_variable_count(model, ActivePowerVariable(), HydroDispatch)
        ####### Check initial condition from initialization step
        check_status_initial_conditions_values(model, ThermalStandard)

        ####### Check variables
        check_variable_count(model, ActivePowerVariable(), ThermalStandard)
        check_variable_count(model, StopVariable(), ThermalStandard)
        check_variable_count(model, OnVariable(), ThermalStandard)
        check_variable_count(model, StartVariable(), ThermalStandard)
        check_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_variable_count(model, ActivePowerVariable(), HydroDispatch)
        check_variable_count(model, OnVariable(), HydroDispatch)
        ####### Check constraints 
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "lb",
        )
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "ub",
        )
        check_constraint_count(model, CommitmentConstraint(), ThermalStandard)
        check_constraint_count(model, CommitmentConstraint(), ThermalStandard; meta = "aux")

        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "lb",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )

        # @test solve!(model) == RunStatus.SUCCESSFUL
    end
end

@testset "Decision Model test for Initialization with RTS GMLC system, Case 4" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalCompactUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, HydroDispatch, HydroDispatchRunOfRiver)

    sys_rts = PSB.build_system(PSITestSystems, "modified_RTS_GMLC_DA_sys")
    for init_time in
        DateTime("2020-01-01T00:00:00"):Month(1):DateTime("2020-12-31T00:00:00"),
        horizon in [24, 48]

        @info(
            "Decision Model initial_conditions test with RTS-GMLC for $init_time and horizon $horizon"
        )
        model = DecisionModel(
            template,
            sys_rts;
            optimizer = SCIP_optimizer,
            initial_time = init_time,
            horizon = horizon,
        )
        @test build!(model; output_dir = mktempdir(cleanup = true)) == BuildStatus.BUILT

        ####### Check initialization problem
        check_initialization_variable_count(
            model,
            PSI.PowerAboveMinimumVariable(),
            ThermalStandard,
        )
        check_initialization_variable_count(model, OnVariable(), ThermalStandard)
        check_initialization_variable_count(model, StopVariable(), ThermalStandard)
        check_initialization_variable_count(model, StartVariable(), ThermalStandard)
        check_initialization_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_initialization_variable_count(model, ActivePowerVariable(), HydroDispatch)

        check_initialization_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "lb",
        )
        check_initialization_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "ub",
        )
        check_initialization_constraint_count(
            model,
            CommitmentConstraint(),
            ThermalStandard,
        )
        check_initialization_constraint_count(
            model,
            CommitmentConstraint(),
            ThermalStandard;
            meta = "aux",
        )
        check_initialization_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )
        check_initialization_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "lb",
        )
        check_initialization_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_initialization_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )

        ####### Check initial condition from initialization step
        check_duration_on_initial_conditions_values(model, ThermalStandard)
        check_duration_off_initial_conditions_values(model, ThermalStandard)
        check_active_power_abovemin_initial_condition_values(model, ThermalStandard)
        check_status_initial_conditions_values(model, ThermalStandard)

        ####### Check variables
        check_variable_count(model, PSI.PowerAboveMinimumVariable(), ThermalStandard)
        check_variable_count(model, OnVariable(), ThermalStandard)
        check_variable_count(model, StopVariable(), ThermalStandard)
        check_variable_count(model, StartVariable(), ThermalStandard)
        check_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_variable_count(model, ActivePowerVariable(), HydroDispatch)

        ####### Check constraints 
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "lb",
        )
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalStandard;
            meta = "ub",
        )
        check_constraint_count(model, RampConstraint(), ThermalStandard)
        check_constraint_count(model, DurationConstraint(), ThermalStandard)
        check_constraint_count(model, CommitmentConstraint(), ThermalStandard)
        check_constraint_count(model, CommitmentConstraint(), ThermalStandard; meta = "aux")
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "lb",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )

        # @test solve!(model) == RunStatus.SUCCESSFUL
    end
end

############ Test with the ERCOT system ############

@testset "Decision Model test for Initialization with TAMU ERCOT system, Case 1" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = ProblemTemplate(NetworkModel(CopperPlatePowerModel; use_slacks = true))
    set_device_model!(template, ThermalMultiStart, ThermalStandardUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, HydroDispatch, HydroDispatchRunOfRiver)
    set_device_model!(template, GenericBattery, BookKeeping)

    sys_ercot = PSB.build_system(PSITestSystems, "tamu_ercot_da_system")
    for init_time in
        DateTime("2018-01-01T00:00:00"):Month(1):DateTime("2018-12-31T00:00:00")
        @info("Decision Model initial_conditions test with RTS-GMLC for $init_time")
        model = DecisionModel(
            template,
            sys_ercot;
            optimizer = SCIP_optimizer,
            initial_time = init_time,
        )
        @test build!(model; output_dir = mktempdir(cleanup = true)) == BuildStatus.BUILT

        ####### Check initialization problem
        check_initialization_variable_count(model, ActivePowerVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, OnVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, StopVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, StartVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_initialization_variable_count(model, ActivePowerVariable(), HydroDispatch)
        check_initialization_variable_count(model, EnergyVariable(), GenericBattery)
        check_initialization_variable_count(model, ActivePowerInVariable(), GenericBattery)
        check_initialization_variable_count(model, ActivePowerOutVariable(), GenericBattery)
        ####### Check initial condition from initialization step
        check_duration_on_initial_conditions_values(model, ThermalMultiStart)
        check_duration_off_initial_conditions_values(model, ThermalMultiStart)
        check_active_power_initial_condition_values(model, ThermalMultiStart)
        check_status_initial_conditions_values(model, ThermalMultiStart)
        check_energy_initial_conditions_values(model, GenericBattery)
        ####### Check variables
        check_variable_count(model, ActivePowerVariable(), ThermalMultiStart)
        check_variable_count(model, StopVariable(), ThermalMultiStart)
        check_variable_count(model, OnVariable(), ThermalMultiStart)
        check_variable_count(model, StartVariable(), ThermalMultiStart)
        check_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_variable_count(model, ActivePowerVariable(), HydroDispatch)
        check_variable_count(model, EnergyVariable(), GenericBattery)
        check_variable_count(model, ActivePowerInVariable(), GenericBattery)
        check_variable_count(model, ActivePowerOutVariable(), GenericBattery)
        ####### Check constraints 
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "lb",
        )
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "ub",
        )
        check_constraint_count(model, DurationConstraint(), ThermalMultiStart)
        check_constraint_count(model, RampConstraint(), ThermalMultiStart)
        check_constraint_count(model, CommitmentConstraint(), ThermalMultiStart)
        check_constraint_count(
            model,
            CommitmentConstraint(),
            ThermalMultiStart;
            meta = "aux",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            OutputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            OutputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(
            model,
            InputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            InputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(
            model,
            EnergyCapacityConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            EnergyCapacityConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(model, EnergyBalanceConstraint(), GenericBattery)

        # @test solve!(model) == RunStatus.SUCCESSFUL
    end
end

@testset "Decision Model test for Initialization with TAMU ERCOT system, Case 2" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = ProblemTemplate(NetworkModel(CopperPlatePowerModel; use_slacks = true))
    set_device_model!(template, ThermalMultiStart, ThermalBasicUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, HydroDispatch, HydroCommitmentRunOfRiver)
    set_device_model!(template, GenericBattery, BookKeeping)

    sys_ercot = PSB.build_system(PSITestSystems, "tamu_ercot_da_system")
    for init_time in
        DateTime("2018-01-01T00:00:00"):Month(1):DateTime("2018-12-31T00:00:00")
        @info("Decision Model initial_conditions test with RTS-GMLC for $init_time")
        model = DecisionModel(
            template,
            sys_ercot;
            optimizer = SCIP_optimizer,
            initial_time = init_time,
        )
        @test build!(model; output_dir = mktempdir(cleanup = true)) == BuildStatus.BUILT

        ####### Check initialization problem
        check_initialization_variable_count(
            model,
            PSI.PowerAboveMinimumVariable(),
            ThermalMultiStart,
        )
        check_initialization_variable_count(model, OnVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, StopVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, StartVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_initialization_variable_count(model, ActivePowerVariable(), HydroDispatch)
        check_initialization_variable_count(model, EnergyVariable(), GenericBattery)
        check_initialization_variable_count(model, ActivePowerInVariable(), GenericBattery)
        check_initialization_variable_count(model, ActivePowerOutVariable(), GenericBattery)
        ####### Check initial condition from initialization step
        check_status_initial_conditions_values(model, ThermalMultiStart)
        check_energy_initial_conditions_values(model, GenericBattery)
        ####### Check variables
        check_variable_count(model, PSI.PowerAboveMinimumVariable(), ThermalMultiStart)
        check_variable_count(model, StopVariable(), ThermalMultiStart)
        check_variable_count(model, OnVariable(), ThermalMultiStart)
        check_variable_count(model, StartVariable(), ThermalMultiStart)
        check_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_variable_count(model, ActivePowerVariable(), HydroDispatch)
        check_variable_count(model, OnVariable(), HydroDispatch)
        check_variable_count(model, EnergyVariable(), GenericBattery)
        check_variable_count(model, ActivePowerInVariable(), GenericBattery)
        check_variable_count(model, ActivePowerOutVariable(), GenericBattery)
        ####### Check constraints 
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "lb",
        )
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "ub",
        )
        check_constraint_count(model, CommitmentConstraint(), ThermalMultiStart)
        check_constraint_count(
            model,
            CommitmentConstraint(),
            ThermalMultiStart;
            meta = "aux",
        )

        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "lb",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            OutputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            OutputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(
            model,
            InputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            InputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(
            model,
            EnergyCapacityConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            EnergyCapacityConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(model, EnergyBalanceConstraint(), GenericBattery)

        # @test solve!(model) == RunStatus.SUCCESSFUL
    end
end

@testset "Decision Model test for Initialization with TAMU ERCOT system, Case 3" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = ProblemTemplate(NetworkModel(CopperPlatePowerModel; use_slacks = true))
    set_device_model!(template, ThermalMultiStart, ThermalMultiStartUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, HydroDispatch, HydroCommitmentRunOfRiver)
    set_device_model!(template, GenericBattery, BatteryAncillaryServices)

    sys_ercot = PSB.build_system(PSITestSystems, "tamu_ercot_da_system")
    for init_time in
        DateTime("2018-01-01T00:00:00"):Month(1):DateTime("2018-12-31T00:00:00")
        @info("Decision Model initial_conditions test with RTS-GMLC for $init_time")
        model = DecisionModel(
            template,
            sys_ercot;
            optimizer = SCIP_optimizer,
            initial_time = init_time,
        )
        @test build!(model; output_dir = mktempdir(cleanup = true)) == BuildStatus.BUILT

        ####### Check initialization problem
        check_initialization_variable_count(
            model,
            PSI.PowerAboveMinimumVariable(),
            ThermalMultiStart,
        )
        check_initialization_variable_count(model, OnVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, StopVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, StartVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_initialization_variable_count(model, ActivePowerVariable(), HydroDispatch)
        check_initialization_variable_count(model, EnergyVariable(), GenericBattery)
        check_initialization_variable_count(model, ActivePowerInVariable(), GenericBattery)
        check_initialization_variable_count(model, ActivePowerOutVariable(), GenericBattery)
        ####### Check initial condition from initialization step
        check_duration_on_initial_conditions_values(model, ThermalMultiStart)
        check_duration_off_initial_conditions_values(model, ThermalMultiStart)
        check_active_power_abovemin_initial_condition_values(model, ThermalMultiStart)
        check_status_initial_conditions_values(model, ThermalMultiStart)
        check_energy_initial_conditions_values(model, GenericBattery)
        ####### Check variables
        check_variable_count(model, PSI.PowerAboveMinimumVariable(), ThermalMultiStart)
        check_variable_count(model, StopVariable(), ThermalMultiStart)
        check_variable_count(model, OnVariable(), ThermalMultiStart)
        check_variable_count(model, StartVariable(), ThermalMultiStart)
        check_variable_count(model, HotStartVariable(), ThermalMultiStart)
        check_variable_count(model, WarmStartVariable(), ThermalMultiStart)
        check_variable_count(model, ColdStartVariable(), ThermalMultiStart)
        check_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_variable_count(model, ActivePowerVariable(), HydroDispatch)
        check_variable_count(model, OnVariable(), HydroDispatch)
        check_variable_count(model, EnergyVariable(), GenericBattery)
        check_variable_count(model, ActivePowerInVariable(), GenericBattery)
        check_variable_count(model, ActivePowerOutVariable(), GenericBattery)
        check_variable_count(model, ReservationVariable(), GenericBattery)
        ####### Check constraints 
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "lb",
        )
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "ubon",
        )
        check_constraint_count(model, CommitmentConstraint(), ThermalMultiStart)
        check_constraint_count(
            model,
            CommitmentConstraint(),
            ThermalMultiStart;
            meta = "aux",
        )
        check_constraint_count(model, DurationConstraint(), ThermalMultiStart)
        check_constraint_count(model, RampConstraint(), ThermalMultiStart)
        check_constraint_count(model, MustRunConstraint(), ThermalMultiStart)
        check_constraint_count(
            model,
            StartupTimeLimitTemperatureConstraint(),
            ThermalMultiStart;
            meta = "hot",
        )
        check_constraint_count(
            model,
            StartupTimeLimitTemperatureConstraint(),
            ThermalMultiStart;
            meta = "warm",
        )

        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "lb",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )

        check_constraint_count(
            model,
            OutputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            OutputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(
            model,
            InputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            InputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(
            model,
            EnergyCapacityConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            EnergyCapacityConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(model, EnergyBalanceConstraint(), GenericBattery)
        # @test solve!(model) == RunStatus.SUCCESSFUL
    end
end

@testset "Decision Model test for Initialization with TAMU ERCOT system, Case 4" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = ProblemTemplate(NetworkModel(CopperPlatePowerModel; use_slacks = true))
    set_device_model!(template, ThermalMultiStart, ThermalCompactUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, HydroDispatch, HydroDispatchRunOfRiver)
    set_device_model!(template, GenericBattery, BookKeeping)

    sys_ercot = PSB.build_system(PSITestSystems, "tamu_ercot_da_system")
    for init_time in
        DateTime("2018-01-01T00:00:00"):Month(1):DateTime("2018-12-31T00:00:00")
        @info("Decision Model initial_conditions test with RTS-GMLC for $init_time")
        model = DecisionModel(
            template,
            sys_ercot;
            optimizer = SCIP_optimizer,
            initial_time = init_time,
        )
        @test build!(model; output_dir = mktempdir(cleanup = true)) == BuildStatus.BUILT

        ####### Check variables
        check_initialization_variable_count(
            model,
            PSI.PowerAboveMinimumVariable(),
            ThermalMultiStart,
        )
        check_initialization_variable_count(model, OnVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, StopVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, StartVariable(), ThermalMultiStart)
        check_initialization_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_initialization_variable_count(model, ActivePowerVariable(), HydroDispatch)

        check_initialization_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "lb",
        )
        check_initialization_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "ub",
        )
        check_initialization_constraint_count(
            model,
            CommitmentConstraint(),
            ThermalMultiStart,
        )
        check_initialization_constraint_count(
            model,
            CommitmentConstraint(),
            ThermalMultiStart;
            meta = "aux",
        )
        check_initialization_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )
        check_initialization_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "lb",
        )
        check_initialization_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_initialization_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )

        ####### Check initial condition from initialization step
        check_duration_on_initial_conditions_values(model, ThermalMultiStart)
        check_duration_off_initial_conditions_values(model, ThermalMultiStart)
        check_active_power_abovemin_initial_condition_values(model, ThermalMultiStart)
        check_energy_initial_conditions_values(model, GenericBattery)
        ####### Check variables
        check_variable_count(model, PSI.PowerAboveMinimumVariable(), ThermalMultiStart)
        check_variable_count(model, OnVariable(), ThermalMultiStart)
        check_variable_count(model, StopVariable(), ThermalMultiStart)
        check_variable_count(model, StartVariable(), ThermalMultiStart)
        check_variable_count(model, ActivePowerVariable(), RenewableDispatch)
        check_variable_count(model, ActivePowerVariable(), HydroDispatch)

        ####### Check constraints 
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "lb",
        )
        check_constraint_count(
            model,
            ActivePowerVariableLimitsConstraint(),
            ThermalMultiStart;
            meta = "ub",
        )
        check_constraint_count(model, RampConstraint(), ThermalMultiStart)
        check_constraint_count(model, DurationConstraint(), ThermalMultiStart)
        check_constraint_count(model, CommitmentConstraint(), ThermalMultiStart)
        check_constraint_count(
            model,
            CommitmentConstraint(),
            ThermalMultiStart;
            meta = "aux",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            RenewableDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableTimeSeriesLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "lb",
        )
        check_constraint_count(
            model,
            PSI.ActivePowerVariableLimitsConstraint(),
            HydroDispatch;
            meta = "ub",
        )
        check_constraint_count(
            model,
            OutputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            OutputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(
            model,
            InputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            InputActivePowerVariableLimitsConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(
            model,
            EnergyCapacityConstraint(),
            GenericBattery;
            meta = "lb",
        )
        check_constraint_count(
            model,
            EnergyCapacityConstraint(),
            GenericBattery;
            meta = "ub",
        )
        check_constraint_count(model, EnergyBalanceConstraint(), GenericBattery)
        # @test solve!(model) == RunStatus.SUCCESSFUL
    end
end
