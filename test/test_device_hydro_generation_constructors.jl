@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type HydroEnergyReservoir, consider changing the device models"
    device_model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        model,
        device_model,
    )
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    @test_logs (:info,) (:warn, warn_message) match_mode = :any mock_construct_device!(
        model,
        device_model,
    )
end

###################################
###### FIXED OUTPUT TESTS #########
###################################

@testset "Hydro DCPLossLess FixedOutput" begin
    device_model = DeviceModel(HydroDispatch, FixedOutput)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with FixedOutput formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, FixedOutput)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

###################################
### RUN OF RIVER DISPATCH TESTS ###
###################################

@testset "Hydro DCPLossLess HydroDispatch with HydroDispatchRunOfRiver formulations" begin
    device_model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroDispatch with HydroDispatchRunOfRiver formulations" begin
    device_model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchRunOfRiver formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroDispatchRunOfRiver formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

###################################
#### RUN OF RIVER COMMIT TESTS ####
###################################

@testset "Hydro DCPLossLess HydroDispatch with HydroCommitmentRunOfRiver formulations" begin
    device_model = DeviceModel(HydroDispatch, HydroCommitmentRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroDispatch with HydroCommitmentRunOfRiver formulations" begin
    device_model = DeviceModel(HydroDispatch, HydroCommitmentRunOfRiver)
    c_sys5_hy = PSB.build_system(PSITestSystems, "c_sys5_hy")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hy)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentRunOfRiver formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroCommitmentRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 48, 0, 48, 24, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroCommitmentRunOfRiver formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroCommitmentRunOfRiver)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, false, 72, 0, 72, 48, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end

#########################################
#### RESERVOIR BUDGET DISPATCH TESTS ####
#########################################

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchReservoirBudget Formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirBudget)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 24, 0, 25, 24, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroDispatchReservoirBudget Formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirBudget)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 48, 0, 49, 48, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

#########################################
#### PUMPED STORAGE DISPATCH TESTS ####
#########################################

@testset "Hydro DCPLossLess HydroPumpedStorage with HydroDispatchPumpedStorage Formulations" begin
    device_model = DeviceModel(HydroPumpedStorage, HydroDispatchPumpedStorage)
    c_sys5_phes_ed = PSB.build_system(PSITestSystems, "c_sys5_phes_ed")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_phes_ed)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 60, 0, 24, 24, 24, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro DCPLossLess HydroPumpedStorage with HydroDispatchPumpedStoragewReservation Formulations" begin
    device_model = DeviceModel(HydroPumpedStorage, HydroDispatchPumpedStoragewReservation)
    c_sys5_phes_ed = PSB.build_system(PSITestSystems, "c_sys5_phes_ed")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_phes_ed)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 72, 0, 24, 24, 24, true)
    psi_checkobjfun_test(model, GAEVF)
end

#########################################
### RESERVOIR BUDGET COMMITMENT TESTS ###
#########################################

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentReservoirBudget Formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirBudget)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 48, 0, 25, 24, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroCommitmentReservoirBudget Formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirBudget)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 72, 0, 49, 48, 0, true)
    psi_checkobjfun_test(model, GAEVF)
end

#########################################
### RESERVOIR STORAGE DISPATCH TESTS ####
#########################################

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirStorage)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd_ems")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 120, 0, 24, 24, 48, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPLossLess HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirStorage)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd_ems")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 144, 0, 48, 48, 48, false)
    psi_checkobjfun_test(model, GAEVF)
end

#########################################
### RESERVOIR STORAGE COMMITMENT TESTS ##
#########################################

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentReservoirStorage Formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirStorage)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd_ems")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 144, 0, 24, 24, 48, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hydro ACPLossLess HydroEnergyReservoir with HydroCommitmentReservoirStorage Formulations" begin
    device_model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirStorage)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd_ems")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_hyd)
    mock_construct_device!(model, device_model)
    moi_tests(model, true, 168, 0, 48, 48, 48, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Solving ED Hydro System using Dispatch Run of River" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_hy")
    networks = [ACPPowerModel, DCPPowerModel]

    test_results = Dict{Any, Float64}(ACPPowerModel => 177526.0, DCPPowerModel => 175521.0)

    for net in networks
        @info("Test solve HydroRoR ED with $(net) network")
        @testset "HydroRoR ED model $(net) and use_parameters = true" begin
            template = get_thermal_dispatch_template_network(net)
            set_device_model!(template, HydroDispatch, HydroDispatchRunOfRiver)
            ED = DecisionModel(
                EconomicDispatchProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
            )
            @test build!(ED; output_dir = mktempdir(cleanup = true)) ==
                  PSI.BuildStatus.BUILT
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[net],
                1000,
            )
        end
    end
end

@testset "Solving ED Hydro System using Commitment Run of River" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_hy")
    net = DCPPowerModel

    template = get_thermal_dispatch_template_network(net)
    set_device_model!(template, HydroDispatch, HydroCommitmentRunOfRiver)

    @testset "HydroRoR ED model $(net) and use_parameters = true" begin
        ED = DecisionModel(UnitCommitmentProblem, template, sys; optimizer = GLPK_optimizer)
        @test build!(ED; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
        psi_checksolve_test(ED, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], 175521.0, 1000)
    end
end

@testset "Solving ED Hydro System using Dispatch with Reservoir" begin
    systems = [
        PSB.build_system(PSITestSystems, "c_sys5_hyd"),
        PSB.build_system(PSITestSystems, "c_sys5_hyd_ems"),
    ]
    networks = [ACPPowerModel, DCPPowerModel]
    models = [HydroDispatchReservoirBudget, HydroDispatchReservoirStorage]
    test_results = Dict{Any, Float64}(
        (ACPPowerModel, HydroDispatchReservoirBudget) => 33423.0,
        (DCPPowerModel, HydroDispatchReservoirBudget) => 33042.0,
        (ACPPowerModel, HydroDispatchReservoirStorage) => 232497.0,
        (DCPPowerModel, HydroDispatchReservoirStorage) => 230153.0,
    )

    for net in networks, (mod, sys) in zip(models, systems)
        @testset "$(mod) ED model on $(net) and use_parameters = true" begin
            template = get_thermal_dispatch_template_network(net)
            set_device_model!(template, HydroEnergyReservoir, mod)

            ED = DecisionModel(
                EconomicDispatchProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
            )
            @test build!(ED; output_dir = mktempdir(cleanup = true)) ==
                  PSI.BuildStatus.BUILT
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[(net, mod)],
                10000,
            )
        end
    end
end

@testset "Solving ED Hydro System using Commitment with Reservoir" begin
    systems = [
        PSB.build_system(PSITestSystems, "c_sys5_hyd"),
        PSB.build_system(PSITestSystems, "c_sys5_hyd_ems"),
    ]
    net = DCPPowerModel
    models = [HydroCommitmentReservoirBudget, HydroCommitmentReservoirStorage]
    test_results = Dict{Any, Float64}(
        HydroCommitmentReservoirBudget => 33042.0,
        HydroCommitmentReservoirStorage => 230153.0,
    )

    for (mod, sys) in zip(models, systems)
        @testset "$(mod) ED model on $(net) and use_parameters = true" begin
            template = get_thermal_dispatch_template_network(net)
            set_device_model!(template, HydroEnergyReservoir, mod)

            ED = DecisionModel(
                UnitCommitmentProblem,
                template,
                sys;
                optimizer = GLPK_optimizer,
            )
            @test build!(ED; output_dir = mktempdir(cleanup = true)) ==
                  PSI.BuildStatus.BUILT
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[mod],
                10000,
            )
        end
    end
end

@testset "HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations (energy target - cases 1b-2b)" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirStorage)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "hydro_test_case_b_sys")

    model = DecisionModel(
        EconomicDispatchProblem,
        template,
        c_sys5_hyd;
        optimizer = Cbc_optimizer,
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 15, 0, 3, 3, 9, false)
    psi_checksolve_test(model, [MOI.OPTIMAL], 5621.0, 10.0)
end

@testset "HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations (energy target - cases 1c-2c)" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirStorage)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "hydro_test_case_c_sys")

    model = DecisionModel(
        EconomicDispatchProblem,
        template,
        c_sys5_hyd;
        optimizer = Cbc_optimizer,
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 15, 0, 3, 3, 9, false)
    psi_checksolve_test(model, [MOI.OPTIMAL], 21.0)
end

@testset "HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations (energy target - cases 1d-2d)" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirStorage)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "hydro_test_case_d_sys")

    model = DecisionModel(
        EconomicDispatchProblem,
        template,
        c_sys5_hyd;
        optimizer = Cbc_optimizer,
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 15, 0, 3, 3, 9, false)
    psi_checksolve_test(model, [MOI.OPTIMAL], -5429.0, 10.0)
end

@testset "HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations (energy target - cases 1e-2e)" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirStorage)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "hydro_test_case_e_sys")

    model = DecisionModel(
        EconomicDispatchProblem,
        template,
        c_sys5_hyd;
        optimizer = Cbc_optimizer,
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 15, 0, 3, 3, 9, false)
    psi_checksolve_test(model, [MOI.OPTIMAL], 21.0, 10.0)
end

@testset "HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations (energy target - cases 1f-2f)" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirStorage)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    c_sys5_hyd = PSB.build_system(PSITestSystems, "hydro_test_case_f_sys")

    model = DecisionModel(
        EconomicDispatchProblem,
        template,
        c_sys5_hyd;
        optimizer = Cbc_optimizer,
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    moi_tests(model, true, 15, 0, 3, 3, 9, false)
    psi_checksolve_test(model, [MOI.OPTIMAL], -17179.0)
end
