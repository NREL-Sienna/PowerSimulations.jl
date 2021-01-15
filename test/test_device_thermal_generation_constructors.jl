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
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.DURATION_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.DURATION_DOWN, PSY.ThermalStandard),
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
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.DURATION_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.DURATION_DOWN, PSY.ThermalStandard),
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
        moi_lbvalue_test(op_problem, :P_lb__ThermalStandard__RangeConstraint, 0.0)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 120, 0, 120, 120, 0, false)
        moi_lbvalue_test(op_problem, :P_lb__ThermalStandard__RangeConstraint, 0.0)
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
        moi_lbvalue_test(op_problem, :P_lb__ThermalStandard__RangeConstraint, 0.0)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

    @info "14-Bus testing"
    c_sys14 = build_system("c_sys14")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 240, 0, 240, 240, 0, false)
        moi_lbvalue_test(op_problem, :P_lb__ThermalStandard__RangeConstraint, 0.0)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

################################### Ramp Limited Testing ##################################
@testset "Thermal Ramp Limited Dispatch With DC - PF" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
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
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalStandard),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalStandard),
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
@testset "Thermal UC With DC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    uc_constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.DURATION_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.DURATION_DOWN, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment)

    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_pglib")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 384, 0, 240, 48, 144, true)
        psi_constraint_test(op_problem, uc_constraint_names)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

end

@testset "Thermal UC With AC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    uc_constraint_names = [
        PSI.make_constraint_name(PSI.RAMP_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.RAMP_DOWN, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.DURATION_UP, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.DURATION_DOWN, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment)

    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_pglib")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 432, 0, 288, 96, 144, true)
        psi_constraint_test(op_problem, uc_constraint_names)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

end

@testset "Thermal Basic UC With DC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalBasicUnitCommitment)

    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_pglib")
    for p in [true, false]
        op_problem =
            OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 384, 0, 96, 48, 144, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end

end

@testset "Thermal Basic UC With AC - PF" begin
    bin_variable_names = [
        PSI.make_variable_name(PSI.ON, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.START, PSY.ThermalMultiStart),
        PSI.make_variable_name(PSI.STOP, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(ThermalMultiStart, ThermalBasicUnitCommitment)

    @info "5-Bus testing"
    c_sys5_uc = build_system("c_sys5_pglib")
    for p in [true, false]
    op_problem =
        OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 432, 0, 144, 96, 144, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart Dispatch With DC - PF" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.ACTIVE_RANGE_IC, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.START_TYPE, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.MUST_RUN_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_WARM, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_HOT, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_UB, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 334, false => 330)
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
        moi_tests(op_problem, p, 528, 0, no_less_than[p], 60, 192, true)
        psi_constraint_test(op_problem, constraint_names)
        psi_checkobjfun_test(op_problem, GAEVF)
    end
end

@testset "Thermal MultiStart Dispatch With AC - PF" begin
    constraint_names = [
        PSI.make_constraint_name(PSI.ACTIVE_RANGE_IC, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.START_TYPE, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.MUST_RUN_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_WARM, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_TIMELIMIT_HOT, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_LB, PSY.ThermalMultiStart),
        PSI.make_constraint_name(PSI.STARTUP_INITIAL_CONDITION_UB, PSY.ThermalMultiStart),
    ]
    model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 382, false => 378)
    @info "5-Bus testing"
    c_sys5_pglib = build_system("c_sys5_pglib")
    for p in [true, false]
        op_problem = OperationsProblem(
            TestOpProblem,
            ACPPowerModel,
            c_sys5_pglib;
            use_parameters = p,
        )
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 576, 0, no_less_than[p], 108, 192, true)
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
    ramp_test_sys = build_system("c_ramp_test")
    template =
        OperationsProblemTemplate(CopperPlatePowerModel, ED_devices, branches, services)
    for p in [true, false]
        ED = OperationsProblem(
            TestOpProblem,
            template,
            ramp_test_sys;
            optimizer = Cbc_optimizer,
            use_parameters = p,
        )
        psi_checksolve_test(ED, [MOI.OPTIMAL], 11191.00)
        moi_tests(ED, p, 10, 0, 20, 10, 5, false)
    end
end

# Testing Duration Constraints
@testset "Solving UC with CopperPlate for testing Duration Constraints" begin
    template =
        OperationsProblemTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(
        TestOpProblem,
        template,
        build_system("c_duration_test");
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8223.50)
    moi_tests(UC, true, 56, 0, 56, 14, 21, true)
end

## PWL linear Cost implementation test
@testset "Solving UC with CopperPlate testing Linear PWL" begin
    template =
        OperationsProblemTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(
        TestOpProblem,
        template,
        build_system("c_linear_pwl_test");
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    psi_checksolve_test(UC, [MOI.OPTIMAL], 9336.736919354838)
    moi_tests(UC, true, 32, 0, 8, 4, 10, true)
end

## PWL SOS-2 Cost implementation test
@testset "Solving UC with CopperPlate testing SOS2 implementation" begin
    template =
        OperationsProblemTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(
        TestOpProblem,
        template,
        build_system("c_sos_pwl_test");
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8500.89716, 10.0)
    moi_tests(UC, true, 32, 0, 8, 4, 14, true)
end

@testset "UC with MarketBid Cost in ThermalGenerators" begin
    sys = build_system("c_market_bid_cost")
    UC_devices[:MSGenerators] =
        DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    template =
        OperationsProblemTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(
        TestOpProblem,
        template,
        sys;
        optimizer = Cbc_optimizer,
        use_parameters = true,
    )
    moi_tests(UC, true, 38, 0, 18, 8, 13, true)
end
