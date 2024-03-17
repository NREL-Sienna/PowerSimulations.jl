precompile_time = @timed using PowerSimulations

using PowerSimulations
const PSI = PowerSimulations
using PowerSystems
const PSY = PowerSystems
using Logging
using PowerSystemCaseBuilder
using PowerNetworkMatrices
using HydroPowerSimulations
using HiGHS
using Dates

open("precompile_time.txt", "a") do io
    write(io, "| $(ARGS[1]) | $(precompile_time.time) |\n")
end

try
    sys_rts_da = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    sys_rts_rt = build_system(PSISystems, "modified_RTS_GMLC_RT_sys")
    sys_rts_realization = build_system(PSISystems, "modified_RTS_GMLC_realization_sys")

    for i in 1:2
        template_uc = ProblemTemplate(
            NetworkModel(
                PTDFPowerModel;
                use_slacks = true,
                PTDF_matrix = PTDF(sys_rts_da),
                duals = [CopperPlateBalanceConstraint],
            ),
        )

        set_device_model!(template_uc, ThermalMultiStart, ThermalCompactUnitCommitment)
        set_device_model!(template_uc, ThermalStandard, ThermalCompactUnitCommitment)
        set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
        set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
        set_device_model!(template_uc, DeviceModel(Line, StaticBranch))
        set_device_model!(template_uc, Transformer2W, StaticBranchUnbounded)
        set_device_model!(template_uc, TapTransformer, StaticBranchUnbounded)
        set_device_model!(template_uc, HydroDispatch, FixedOutput)
        set_device_model!(template_uc, HydroEnergyReservoir, HydroDispatchRunOfRiver)
        set_service_model!(
            template_uc,
            ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
        )
        set_service_model!(
            template_uc,
            ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
        )

        template_ed = deepcopy(template_uc)
        set_device_model!(template_ed, ThermalMultiStart, ThermalBasicDispatch)
        set_device_model!(template_ed, ThermalStandard, ThermalBasicDispatch)
        set_device_model!(template_ed, HydroDispatch, HydroDispatchRunOfRiver)
        set_device_model!(template_ed, HydroEnergyReservoir, HydroDispatchRunOfRiver)

        template_em = deepcopy(template_ed)
        set_device_model!(template_ed, Line, StaticBranchUnbounded)
        empty!(template_em.services)

        models = SimulationModels(;
            decision_models = [
                DecisionModel(
                    template_uc,
                    sys_rts_da;
                    name = "UC",
                    optimizer = optimizer_with_attributes(HiGHS.Optimizer,
                        "mip_rel_gap" => 0.01),
                    system_to_file = false,
                    initialize_model = true,
                    optimizer_solve_log_print = true,
                    direct_mode_optimizer = true,
                    check_numerical_bounds = false,
                ),
                DecisionModel(
                    template_ed,
                    sys_rts_rt;
                    name = "ED",
                    optimizer = optimizer_with_attributes(HiGHS.Optimizer,
                        "mip_rel_gap" => 0.01),
                    system_to_file = false,
                    initialize_model = true,
                    check_numerical_bounds = false,
                    #export_pwl_vars = true,
                ),
            ],
            emulation_model = EmulationModel(
                template_em,
                sys_rts_realization;
                name = "PF",
                optimizer = optimizer_with_attributes(HiGHS.Optimizer),
            ),
        )

        sequence = SimulationSequence(;
            models = models,
            feedforwards = Dict(
                "ED" => [
                    SemiContinuousFeedforward(;
                        component_type = ThermalStandard,
                        source = OnVariable,
                        affected_values = [ActivePowerVariable],
                    ),
                ],
                "PF" => [
                    SemiContinuousFeedforward(;
                        component_type = ThermalStandard,
                        source = OnVariable,
                        affected_values = [ActivePowerVariable],
                    ),
                ],
            ),
            ini_cond_chronology = InterProblemChronology(),
        )

        sim = Simulation(;
            name = "compact_sim",
            steps = 3,
            models = models,
            sequence = sequence,
            initial_time = DateTime("2020-01-01T00:00:00"),
            simulation_folder = mktempdir(; cleanup = true),
        )

        build_out, time_build, _, _ =
            @timed build!(sim; console_level = Logging.Error, serialize = false)

        if build_out == PSI.BuildStatus.BUILT
            name = i > 1 ? "Postcompile" : "Precompile"
            open("build_time.txt", "a") do io
                write(io, "| $(ARGS[1])-Build Time $name | $(time_build) |\n")
            end
        else
            open("build_time.txt", "a") do io
                write(io, "| $(ARGS[1])- Build Time $name | FAILED TO TEST |\n")
            end
        end

        solve_out, time_solve, _, _ = execute!(sim; enable_progress_bar = false)

        if solve_out == PSI.RunStatus.SUCCESSFUL
            name = i > 1 ? "Postcompile" : "Precompile"
            open("solve_time.txt", "a") do io
                write(io, "| $(ARGS[1])-Solve Time $name | $(time_solve) |\n")
            end
        else
            open("solve_time.txt", "a") do io
                write(io, "| $(ARGS[1])- Solve Time $name | FAILED TO TEST |\n")
            end
        end
    end
catch e
    rethrow(e)
    open("build_time.txt", "a") do io
        write(io, "| $(ARGS[1])- Build Time | FAILED TO TEST |\n")
    end
end
