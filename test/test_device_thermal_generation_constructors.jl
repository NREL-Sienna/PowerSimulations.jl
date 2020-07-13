@testset "ThermalGen data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type ThermalStandard, consider changing the device models"
    model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)
    c_sys5_re_only = build_system("c_sys5_re_only")
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, build_system("c_sys5_re_only"))
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Thermal, model)
end

################################### Unit Commitment tests ##################################
@testset "Thermal UC With DC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]
    uc_constraint_names = [
        PSI.constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
        PSI.constraint_name(PSI.DURATION_UP, PSY.ThermalStandard),
        PSI.constraint_name(PSI.DURATION_DOWN, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)

    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_uc")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, false, 480, 0, 480, 120, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc; use_parameters = true)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, true, 480, 0, 480, 120, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 480, 0, 240, 120, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal UC With AC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]
    uc_constraint_names = [
        PSI.constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
        PSI.constraint_name(PSI.DURATION_UP, PSY.ThermalStandard),
        PSI.constraint_name(PSI.DURATION_DOWN, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)

    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_uc")
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, false, 600, 0, 600, 240, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem =
        OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc; use_parameters = true)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, true, 600, 0, 600, 240, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 600, 0, 360, 240, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

################################### Basic Unit Commitment tests ############################
@testset "Thermal Basic UC With DC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment)

    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_uc")
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, false, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc; use_parameters = true)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, true, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 480, 0, 240, 120, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Basic UC With AC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.START, PSY.ThermalStandard),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment)

    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_uc")
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, false, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem =
        OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc; use_parameters = true)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, true, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 600, 0, 360, 240, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

################################### Basic Dispatch tests ###################################
@testset "Thermal Dispatch With DC - PF" begin
    model = DeviceModel(ThermalStandard, ThermalDispatch)
    @info "5-Bus testing"
    c_sys5 = build_system("c_sys5")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Dispatch With AC - PF" begin
    model = DeviceModel(ThermalStandard, ThermalDispatch)
    @info "5-Bus testing"
    c_sys5 = build_system("c_sys5")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

################################### No Minimum Dispatch tests ##############################

@testset "Thermal Dispatch NoMin With DC - PF" begin
    model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    @info "5-Bus testing"
    c_sys5 = build_system("c_sys5")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        moi_lbvalue_test(
            op_problem,
            PSI.constraint_name(PSI.ACTIVE_RANGE_LB, PSY.ThermalStandard),
            0.0,
        )
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        moi_lbvalue_test(
            op_problem,
            PSI.constraint_name(PSI.ACTIVE_RANGE_LB, PSY.ThermalStandard),
            0.0,
        )
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Dispatch NoMin With AC - PF" begin
    model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    @info "5-Bus testing"
    c_sys5 = build_system("c_sys5")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        moi_lbvalue_test(
            op_problem,
            PSI.constraint_name(PSI.ACTIVE_RANGE_LB, PSY.ThermalStandard),
            0.0,
        )
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        moi_lbvalue_test(
            op_problem,
            PSI.constraint_name(PSI.ACTIVE_RANGE_LB, PSY.ThermalStandard),
            0.0,
        )
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

################################### Ramp Limited Testing ##################################
@testset "Thermal Ramp Limited Dispatch With DC - PF" begin
    constraint_names = [
        PSI.constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalRampLimited)
    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_uc")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 120, 0, 216, 120, 0, false)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Ramp Limited Dispatch With AC - PF" begin
    constraint_names = [
        PSI.constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
    ]
    model = DeviceModel(ThermalStandard, ThermalRampLimited)
    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_uc")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 240, 0, 336, 240, 0, false)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

################################### ThermalMultiStart Testing ##################################

@testset "Thermal MultiStart Dispatch With DC - PF" begin
    constraint_names = [
        PSI.constraint_name(PSI.ACTIVE_RANGE_IC, PSY.ThermalMultiStart),
        PSI.constraint_name(PSI.START_TYPE, PSY.ThermalMultiStart),
        PSI.constraint_name(PSI.MUST_RUN_LB, PSY.ThermalMultiStart),
        PSI.constraint_name(PSI.STARTUP_TIMELIMIT_WARM, PSY.ThermalMultiStart),
        PSI.constraint_name(PSI.STARTUP_TIMELIMIT_HOT, PSY.ThermalMultiStart),
        PSI.constraint_name(PSI.STARTUP_INITIAL_CONDITION_LB, PSY.ThermalMultiStart),
        PSI.constraint_name(PSI.STARTUP_INITIAL_CONDITION_UB, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    @info "5-Bus testing"
    c_sys5_pglib = build_system("c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            TestOpProblem,
            DCPPowerModel,
            c_sys5_pglib;
            use_parameters = p,
        )
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 528, 0, 238, 60, 192, true)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

############################# UC validation tests ##########################################
branches = Dict{Symbol, DeviceModel}()
services = Dict{Symbol, ServiceModel}()
ED_devices = Dict{Symbol, DeviceModel}(
    :Generators => DeviceModel(ThermalStandard, ThermalRampLimited),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
)
UC_devices = Dict{Symbol, DeviceModel}(
    :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
)
# Testing Ramping Constraint
@testset "Solving ED with CopperPlate for testing Ramping Constraints" begin
    node = Bus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing)
    load = PowerLoad("Bus1", true, node, nothing, 0.4, 0.9861, 1.0, 2.0)
    DA_ramp = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  4:00:00",
            "d/m/y  H:M:S",
        ),
    )
    gen_ramp = [
        ThermalStandard(
            "Alta",
            true,
            true,
            node,
            0.20,
            0.010,
            0.5,
            PrimeMovers.ST,
            ThermalFuels.COAL,
            (min = 0.0, max = 0.40),
            nothing,
            nothing,
            nothing,
            ThreePartCost((0.0, 1400.0), 0.0, 4.0, 2.0),
            1.0,
        ),
        ThermalStandard(
            "Park City",
            true,
            true,
            node,
            0.70,
            0.20,
            2.0,
            PrimeMovers.ST,
            ThermalFuels.COAL,
            (min = 0.7, max = 2.20),
            nothing,
            (up = 0.010625, down = 0.010625),
            nothing,
            ThreePartCost((0.0, 1500.0), 0.0, 1.5, 0.75),
            1.0,
        ),
    ]
    ramp_load = [0.9, 1.1, 2.485, 2.175, 0.9]
    load_forecast_ramp = Deterministic("get_maxactivepower", TimeArray(DA_ramp, ramp_load))
    ramp_test_sys = System(100.0)
    add_component!(ramp_test_sys, node)
    add_component!(ramp_test_sys, load)
    add_component!(ramp_test_sys, gen_ramp[1])
    add_component!(ramp_test_sys, gen_ramp[2])
    add_forecast!(ramp_test_sys, load, load_forecast_ramp)

    template =
        OperationsProblemTemplate(CopperPlatePowerModel, ED_devices, branches, services)
    ED = OperationsProblem(
        TestOpProblem,
        template,
        ramp_test_sys;
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    psi_checksolve_test(ED, [MOI.OPTIMAL], 11191.00)
    moi_tests(ED, true, 10, 0, 20, 10, 5, false)
end

# Testing Duration Constraints
@testset "Solving UC with CopperPlate for testing Duration Constraints" begin
    node = Bus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing)
    load = PowerLoad("Bus1", true, node, nothing, 0.4, 0.9861, 1.0, 2.0)
    DA_dur = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  6:00:00",
            "d/m/y  H:M:S",
        ),
    )
    gens_dur = [
        ThermalStandard(
            name = "Alta",
            available = true,
            status = true,
            bus = node,
            activepower = 0.40,
            reactivepower = 0.010,
            rating = 0.5,
            primemover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            activepowerlimits = (min = 0.3, max = 0.9),
            reactivepowerlimits = nothing,
            ramplimits = nothing,
            timelimits = (up = 4, down = 2),
            op_cost = ThreePartCost((0.0, 1400.0), 0.0, 4.0, 2.0),
            basepower = 1.0,
            time_at_status = 2.0,
        ),
        ThermalStandard(
            name = "Park City",
            available = true,
            status = false,
            bus = node,
            activepower = 1.70,
            reactivepower = 0.20,
            rating = 2.2125,
            primemover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            activepowerlimits = (min = 0.7, max = 2.2),
            reactivepowerlimits = nothing,
            ramplimits = nothing,
            timelimits = (up = 6, down = 4),
            op_cost = ThreePartCost((0.0, 1500.0), 0.0, 1.5, 0.75),
            basepower = 1.0,
            time_at_status = 3.0,
        ),
    ]

    duration_load = [0.3, 0.6, 0.8, 0.7, 1.7, 0.9, 0.7]
    load_forecast_dur =
        Deterministic("get_maxactivepower", TimeArray(DA_dur, duration_load))
    duration_test_sys = System(100.0)
    add_component!(duration_test_sys, node)
    add_component!(duration_test_sys, load)
    add_component!(duration_test_sys, gens_dur[1])
    add_component!(duration_test_sys, gens_dur[2])
    add_forecast!(duration_test_sys, load, load_forecast_dur)

    template =
        OperationsProblemTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(
        TestOpProblem,
        template,
        duration_test_sys;
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8223.50)
    moi_tests(UC, true, 56, 0, 56, 14, 21, true)
end

## PWL linear Cost implementation test
@testset "Solving UC with CopperPlate testing Linear PWL" begin
    node = Bus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing)
    load = PowerLoad("Bus1", true, node, nothing, 0.4, 0.9861, 1.0, 2.0)
    gens_cost = [
        ThermalStandard(
            "Alta",
            true,
            true,
            node,
            0.52,
            0.010,
            0.5,
            PrimeMovers.ST,
            ThermalFuels.COAL,
            (min = 0.22, max = 0.55),
            nothing,
            nothing,
            nothing,
            ThreePartCost(
                [(589.99, 0.220), (884.99, 0.33), (1210.04, 0.44), (1543.44, 0.55)],
                532.44,
                5665.23,
                0.0,
            ),
            1.0,
        ),
        ThermalStandard(
            "Park City",
            true,
            true,
            node,
            0.62,
            0.20,
            2.2125,
            PrimeMovers.ST,
            ThermalFuels.COAL,
            (min = 0.62, max = 1.55),
            nothing,
            nothing,
            nothing,
            ThreePartCost(
                [(1264.80, 0.62), (1897.20, 0.93), (2594.4787, 1.24), (3433.04, 1.55)],
                235.397,
                5665.23,
                0.0,
            ),
            1.0,
        ),
    ]
    DA_cost = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  1:00:00",
            "d/m/y  H:M:S",
        ),
    )
    cost_load = [1.3, 2.1]
    load_forecast_cost = Deterministic("get_maxactivepower", TimeArray(DA_cost, cost_load))
    cost_test_sys = System(100.0)
    add_component!(cost_test_sys, node)
    add_component!(cost_test_sys, load)
    add_component!(cost_test_sys, gens_cost[1])
    add_component!(cost_test_sys, gens_cost[2])
    add_forecast!(cost_test_sys, load, load_forecast_cost)

    template =
        OperationsProblemTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(
        TestOpProblem,
        template,
        cost_test_sys;
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    psi_checksolve_test(UC, [MOI.OPTIMAL], 9336.736919354838)
    moi_tests(UC, true, 32, 0, 8, 4, 10, true)
end

## PWL SOS-2 Cost implementation test
@testset "Solving UC with CopperPlate testing SOS2 implementation" begin
    node = Bus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing)
    load = PowerLoad("Bus1", true, node, nothing, 0.4, 0.9861, 1.0, 2.0)
    gens_cost_sos = [
        ThermalStandard(
            "Alta",
            true,
            true,
            node,
            0.52,
            0.010,
            0.5,
            PrimeMovers.ST,
            ThermalFuels.COAL,
            (min = 0.22, max = 0.55),
            nothing,
            nothing,
            nothing,
            ThreePartCost(
                [(1122.43, 0.22), (1617.43, 0.33), (1742.48, 0.44), (2075.88, 0.55)],
                0.0,
                5665.23,
                0.0,
            ),
            1.0,
        ),
        ThermalStandard(
            "Park City",
            true,
            true,
            node,
            0.62,
            0.20,
            2.2125,
            PrimeMovers.ST,
            ThermalFuels.COAL,
            (min = 0.62, max = 1.55),
            nothing,
            nothing,
            nothing,
            ThreePartCost(
                [(1500.19, 0.62), (2132.59, 0.929), (2829.875, 1.24), (2831.444, 1.55)],
                0.0,
                5665.23,
                0.0,
            ),
            1.0,
        ),
    ]
    DA_cost_sos = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  1:00:00",
            "d/m/y  H:M:S",
        ),
    )
    cost_sos_load = [1.3, 2.1]
    load_forecast_cost_sos =
        Deterministic("get_maxactivepower", TimeArray(DA_cost_sos, cost_sos_load))
    cost_test_sos_sys = System(100.0)
    add_component!(cost_test_sos_sys, node)
    add_component!(cost_test_sos_sys, load)
    add_component!(cost_test_sos_sys, gens_cost_sos[1])
    add_component!(cost_test_sos_sys, gens_cost_sos[2])
    add_forecast!(cost_test_sos_sys, load, load_forecast_cost_sos)

    for g in gens_cost_sos
        @test PSI._pwlparamcheck(PSY.get_op_cost(g).variable) == false
    end

    template =
        OperationsProblemTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(
        TestOpProblem,
        template,
        cost_test_sos_sys;
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8500.89716, 10.0)
    moi_tests(UC, true, 32, 0, 8, 4, 14, true)
end
