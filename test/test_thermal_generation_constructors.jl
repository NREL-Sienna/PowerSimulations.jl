@testset "ThermalGen data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type ThermalStandard, consider changing the device models"
    model = DeviceModel(ThermalStandard, PSI.ThermalStandardUnitCommitment)
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_re_only)
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Thermal, model)
end

################################### Unit Commitment tests ##################################
@testset "Thermal UC With DC - PF" begin
    bin_variable_names = [:ON_ThermalStandard,
                          :START_ThermalStandard,
                          :STOP_ThermalStandard]
    uc_constraint_names = [:ramp_up_ThermalStandard,
                           :ramp_dn_ThermalStandard,
                           :duration_up_ThermalStandard,
                           :duration_dn_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalStandardUnitCommitment)

    @info "5-Bus testing"
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, false, 480, 0, 480, 120, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc; use_parameters = true)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, true, 480, 0, 480, 120, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    @info "14-Bus testing"
    for p in [true, false]
        op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 480, 0, 240, 120, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal UC With AC - PF" begin
    bin_variable_names = [:ON_ThermalStandard,
                          :START_ThermalStandard,
                          :STOP_ThermalStandard]
    uc_constraint_names = [:ramp_up_ThermalStandard,
                           :ramp_dn_ThermalStandard,
                           :duration_up_ThermalStandard,
                           :duration_dn_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalStandardUnitCommitment)

    @info "5-Bus testing"
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, false, 600, 0, 600, 240, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc; use_parameters = true)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, true, 600, 0, 600, 240, 120, true)
    psi_constraint_test(op_problem, uc_constraint_names)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    @info "14-Bus testing"
    for p in [true, false]
        op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 600, 0, 360, 240, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

################################### Basic Unit Commitment tests ############################
@testset "Thermal Basic UC With DC - PF" begin
    bin_variable_names = [:ON_ThermalStandard,
                          :START_ThermalStandard,
                          :STOP_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicUnitCommitment)

    @info "5-Bus testing"
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, false, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_uc; use_parameters = true)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, true, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    @info "14-Bus testing"
    for p in [true, false]
        op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 480, 0, 240, 120, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end

@testset "Thermal Basic UC With AC - PF" begin
    bin_variable_names = [:ON_ThermalStandard,
                          :START_ThermalStandard,
                          :STOP_ThermalStandard]
     model = DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicUnitCommitment)

    @info "5-Bus testing"
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, false, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_uc; use_parameters = true)
    construct_device!(op_problem, :Thermal, model)
    moi_tests(op_problem, true, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(op_problem, bin_variable_names)
    psi_checkobjfun_test(op_problem, GAEVF)

    @info "14-Bus testing"
    for p in [true, false]
        op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys14; use_parameters = p)
        construct_device!(op_problem, :Thermal, model)
        moi_tests(op_problem, p, 600, 0, 360, 240, 120, true)
        psi_checkbinvar_test(op_problem, bin_variable_names)
        psi_checkobjfun_test(op_problem, GQEVF)
    end
end


################################### Basic Dispatch tests ###################################
@testset "Thermal Dispatch With DC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 0, 120, 120, 0, false)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 0, 120, 120, 0, false)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


@testset "Thermal Dispatch With AC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, ACPPowerModel, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 0, 240, 240, 0, false)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, ACPPowerModel, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 0, 240, 240, 0, false)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


################################### No Minimum Dispatch tests ##############################

@testset "Thermal Dispatch NoMin With DC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatchNoMin)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 0, 120, 120, 0, false)
        moi_lbvalue_test(op_model, :activerange_lb_ThermalStandard, 0.0)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 0, 120, 120, 0, false)
        moi_lbvalue_test(op_model, :activerange_lb_ThermalStandard, 0.0)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


@testset "Thermal Dispatch NoMin With AC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatchNoMin)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, ACPPowerModel, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 0, 240, 240, 0, false)
        moi_lbvalue_test(op_model, :activerange_lb_ThermalStandard, 0.0)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, ACPPowerModel, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 0, 240, 240, 0, false)
        moi_lbvalue_test(op_model, :activerange_lb_ThermalStandard, 0.0)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


################################### Ramp Limited Testing ##################################
@testset "Thermal Ramp Limited Dispatch With DC - PF" begin
    constraint_names = [:ramp_up_ThermalStandard, :ramp_dn_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys5_uc; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 0, 216, 120, 0, false)
        psi_constraint_test(op_model, constraint_names)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, DCPPowerModel, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 0, 120, 120, 0, false)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


@testset "Thermal Ramp Limited Dispatch With AC - PF" begin
    constraint_names = [:ramp_up_ThermalStandard, :ramp_dn_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, ACPPowerModel, c_sys5_uc; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 0, 336, 240, 0, false)
        psi_constraint_test(op_model, constraint_names)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, ACPPowerModel, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 0, 240, 240, 0, false)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


############################# UC validation tests ##########################################
branches = Dict{Symbol, PSI.DeviceModel}()
services = Dict{Symbol, PSI.ServiceModel}()
ED_devices = Dict{Symbol, DeviceModel}(:Generators => PSI.DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited),
                                        :Loads =>  PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
UC_devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalStandardUnitCommitment),
                                        :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
# Testing Ramping Constraint
@testset "Solving UC with CopperPlate for testing Ramping Constraints" begin
node = Bus(1,"nodeA", "PV", 0, 1.0, (min = 0.9, max=1.05), 230)
load = PowerLoad("Bus1", true, node,nothing, 0.4, 0.9861, 1.0, 2.0)
    DA_ramp = collect(DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):
                        Hour(1):
                        DateTime("1/1/2024  4:00:00", "d/m/y  H:M:S"))
    gen_ramp = [ThermalStandard("Alta", true, node,0.20, 0.010,
            TechThermal(0.5,PSY.PrimeMovers(6),PSY.ThermalFuels(6),
                            (min=0.0, max=0.40), nothing,
                            nothing, nothing),
            ThreePartCost((0.0, 1400.0), 0.0, 4.0, 2.0)
            ),
            ThermalStandard("Park City", true, node,0.70,0.20,
                TechThermal(2.0,PSY.PrimeMovers(6),PSY.ThermalFuels(6),
                            (min=0.7, max=2.20), nothing,
                            (up = 0.010625, down= 0.010625),nothing),
                ThreePartCost((0.0, 1500.0), 0.0, 1.5, 0.75)
            )];
    ramp_load = [ 0.9, 1.1, 2.485, 2.175, 0.9];
    load_forecast_ramp = Deterministic("maxactivepower", TimeArray(DA_ramp, ramp_load))
    ramp_test_sys = PSY.System(100.0)
    add_component!(ramp_test_sys, node)
    add_component!(ramp_test_sys, load)
    add_component!(ramp_test_sys, gen_ramp[1])
    add_component!(ramp_test_sys, gen_ramp[2])
    add_forecast!(ramp_test_sys, load, load_forecast_ramp)

    template = OperationsTemplate(CopperPlatePowerModel, ED_devices, branches, services)
    ED = OperationsProblem(TestOpProblem, template,
                        ramp_test_sys; optimizer = Cbc_optimizer,
                        use_parameters = true)
    psi_checksolve_test(ED, [MOI.OPTIMAL], 11191.00)
    moi_tests(ED, true, 10, 0, 20, 10, 5, false)
end

# Testing Duration Constraints
@testset "Solving UC with CopperPlate for testing Duration Constraints" begin
node = Bus(1,"nodeA", "PV", 0, 1.0, (min = 0.9, max=1.05), 230)
load = PowerLoad("Bus1", true, node,nothing, 0.4, 0.9861, 1.0, 2.0)
    DA_dur  = collect(DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):
                        Hour(1):
                        DateTime("1/1/2024  6:00:00", "d/m/y  H:M:S"))
    gens_dur = [ThermalStandard("Alta", true, node,0.40, 0.010,
            TechThermal(0.5,PSY.PrimeMovers(6),PSY.ThermalFuels(6),
                            (min=0.3, max=0.9), nothing,
                            nothing, (up=4, down=2)),
            ThreePartCost((0.0, 1400.0), 0.0, 4.0, 2.0)
            ),
            ThermalStandard("Park City", true, node,1.70,0.20,
                TechThermal(2.2125,PSY.PrimeMovers(6),PSY.ThermalFuels(6),
                                (min=0.7, max=2.2), nothing,
                                nothing, (up=6, down=4)),
                ThreePartCost((0.0, 1500.0), 0.0, 1.5, 0.75)
            )];

    duration_load = [0.3, 0.6, 0.8, 0.7, 1.7, 0.9, 0.7]
    load_forecast_dur = Deterministic("maxactivepower", TimeArray(DA_dur, duration_load))
    duration_test_sys = PSY.System(100.0)
    add_component!(duration_test_sys, node)
    add_component!(duration_test_sys, load)
    add_component!(duration_test_sys, gens_dur[1])
    add_component!(duration_test_sys, gens_dur[2])
    add_forecast!(duration_test_sys, load, load_forecast_dur)

    status = [1.0,0.0]
    up_time = [2.0,0.0]
    down_time = [0.0,3.0]

    alta = gens_dur[1]
    init_cond = PSI.DICKDA()
    init_cond[PSI.ICKey(PSI.DeviceStatus,typeof(alta))] = build_init(gens_dur, status)
    init_cond[PSI.ICKey(PSI.TimeDurationON,typeof(alta))] = build_init(gens_dur, up_time)
    init_cond[PSI.ICKey(PSI.TimeDurationOFF,typeof(alta))] = build_init(gens_dur, down_time)


    template = OperationsTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(TestOpProblem, template,
                        duration_test_sys; optimizer = Cbc_optimizer,
                        use_parameters = true, initial_conditions = init_cond)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8223.50)
    moi_tests(UC, true, 56, 0, 56, 14, 21, true)
end

## PWL linear Cost implementation test
@testset "Solving UC with CopperPlate testing Linear PWL" begin
node = Bus(1,"nodeA", "PV", 0, 1.0, (min = 0.9, max=1.05), 230)
load = PowerLoad("Bus1", true, node,nothing, 0.4, 0.9861, 1.0, 2.0)
    gens_cost = [ThermalStandard("Alta", true, node,0.52, 0.010,
            TechThermal(0.5,PSY.PrimeMovers(6),PSY.ThermalFuels(6),
                            (min = 0.22, max = 0.55), nothing,
                            nothing, nothing),
            ThreePartCost([ (589.99, 0.220),(884.99, 0.33)
                    ,(1210.04, 0.44),(1543.44, 0.55)],532.44, 5665.23, 0.0)
            ),
            ThermalStandard("Park City", true, node,0.62,0.20,
                TechThermal(2.2125,PSY.PrimeMovers(6),PSY.ThermalFuels(6),
                            (min = 0.62, max = 1.55), nothing,
                            nothing, nothing),
                ThreePartCost([   (1264.80, 0.62),(1897.20, 0.93),
                    (2594.4787, 1.24),(3433.04, 1.55)   ], 235.397, 5665.23, 0.0)
            )];
    DA_cost  = collect(DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):
                        Hour(1):
                        DateTime("1/1/2024  1:00:00", "d/m/y  H:M:S"))
    cost_load = [1.3,2.1];
    load_forecast_cost = Deterministic("maxactivepower", TimeArray(DA_cost, cost_load))
    cost_test_sys = PSY.System(100.0)
    add_component!(cost_test_sys, node)
    add_component!(cost_test_sys, load)
    add_component!(cost_test_sys, gens_cost[1])
    add_component!(cost_test_sys, gens_cost[2])
    add_forecast!(cost_test_sys, load, load_forecast_cost)


    template = OperationsTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(TestOpProblem, template,
                        cost_test_sys; optimizer = Cbc_optimizer,
                        use_parameters = true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 9336.736919354838)
    moi_tests(UC, true, 32, 0, 8, 4, 10, true)
end

## PWL SOS-2 Cost implementation test
@testset "Solving UC with CopperPlate testing SOS2 implementation" begin
    node = Bus(1,"nodeA", "PV", 0, 1.0, (min = 0.9, max=1.05), 230)
    load = PowerLoad("Bus1", true, node,nothing, 0.4, 0.9861, 1.0, 2.0)
    gens_cost_sos = [ThermalStandard("Alta", true, node,0.52, 0.010,
            TechThermal(0.5,PSY.PrimeMovers(6),PSY.ThermalFuels(6),
                            (min = 0.22, max = 0.55), nothing,
                            nothing, nothing),
            ThreePartCost([ (1122.43, 0.22),(1417.43, 0.33),
                    (1742.48, 0.44),(2075.88, 0.55) ],0.0, 5665.23, 0.0)
            ),
            ThermalStandard("Park City", true, node,0.62,0.20,
                TechThermal(2.2125,PSY.PrimeMovers(6),PSY.ThermalFuels(6),
                            (min = 0.62, max = 1.55), nothing,
                            nothing, nothing),
                ThreePartCost([ (1500.19, 0.62),(2132.59, 0.929),
                    (2829.875, 1.24),(3668.444, 1.55)], 0.0, 5665.23, 0.0)
            )];
    DA_cost_sos   = collect(DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):
                        Hour(1):
                        DateTime("1/1/2024  1:00:00", "d/m/y  H:M:S"))
    cost_sos_load = [1.3,2.1];
    load_forecast_cost_sos  = Deterministic("maxactivepower", TimeArray(DA_cost_sos, cost_sos_load))
    cost_test_sos_sys = PSY.System(100.0)
    add_component!(cost_test_sos_sys, node)
    add_component!(cost_test_sos_sys, load)
    add_component!(cost_test_sos_sys, gens_cost_sos[1])
    add_component!(cost_test_sos_sys, gens_cost_sos[2])
    add_forecast!(cost_test_sos_sys, load, load_forecast_cost_sos)

    template = OperationsTemplate(CopperPlatePowerModel, UC_devices, branches, services)
    UC = OperationsProblem(TestOpProblem, template,
                        cost_test_sos_sys; optimizer = Cbc_optimizer,
                        use_parameters = true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 9336.736919,10.0)
    moi_tests(UC, true, 32, 0, 8, 4, 14, true)
end
