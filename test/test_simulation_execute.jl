function test_single_stage_sequential(in_memory, rebuild, export_model)
    tmp_dir = mktempdir(; cleanup = true)
    template_ed = get_template_nomin_ed_simulation()
    c_sys = PSB.build_system(PSITestSystems, "c_sys5_uc")
    models = SimulationModels([
        DecisionModel(
            template_ed,
            c_sys;
            name = "ED",
            optimizer = HiGHS_optimizer,
            rebuild_model = rebuild,
            export_optimization_model = export_model,
        ),
    ])
    test_sequence =
        SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
        )
    sim_single = Simulation(;
        name = "consecutive",
        steps = 2,
        models = models,
        sequence = test_sequence,
        simulation_folder = tmp_dir,
    )
    build_out = build!(sim_single)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim_single; in_memory = in_memory)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    return tmp_dir
end

@testset "Single stage sequential tests" begin
    for in_memory in (true, false), rebuild in (true, false)
        test_single_stage_sequential(
            in_memory,
            rebuild,
            PSI.OptimizationModelExportFormat.NONE,
        )
    end
end

# A load formulation that adds nothing and records the initial time each build reads at.
struct InitialTimeProbe <: POM.AbstractLoadFormulation end
const PROBED_INITIAL_TIMES = Dates.DateTime[]
POM.get_default_time_series_names(::Type{PowerLoad}, ::Type{InitialTimeProbe}) =
    Dict{Type{<:IOM.TimeSeriesParameter}, String}()
POM.get_default_attributes(::Type{PowerLoad}, ::Type{InitialTimeProbe}) =
    Dict{String, Any}()
function POM.construct_device!(
    container::IOM.OptimizationContainer,
    ::PSY.System,
    ::IOM.ArgumentConstructStage,
    ::IOM.DeviceModel{PowerLoad, InitialTimeProbe},
    ::IOM.NetworkModel{CopperPlateNetworkModel},
)
    push!(PROBED_INITIAL_TIMES, IOM.get_initial_time(container))
    return
end
POM.construct_device!(
    ::IOM.OptimizationContainer,
    ::PSY.System,
    ::IOM.ModelConstructStage,
    ::IOM.DeviceModel{PowerLoad, InitialTimeProbe},
    ::IOM.NetworkModel{CopperPlateNetworkModel},
) = nothing

@testset "A rebuilt model builds at the step it solves" begin
    empty!(PROBED_INITIAL_TIMES)
    template = get_template_nomin_ed_simulation()
    set_device_model!(template, PowerLoad, InitialTimeProbe)
    c_sys = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(template, c_sys; name = "ED", optimizer = HiGHS_optimizer,
        rebuild_model = true)
    models = SimulationModels([model])
    sequence = SimulationSequence(; models, ini_cond_chronology = InterProblemChronology())
    sim = Simulation(; name = "rebuild_time", steps = 2, models, sequence,
        simulation_folder = mktempdir(; cleanup = true))
    @test build!(sim) == PSI.SimulationBuildStatus.BUILT
    @test execute!(sim; in_memory = true) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    t0 = PSI.get_initial_time(sim)
    @test PROBED_INITIAL_TIMES == [t0, t0 + IOM.get_interval(sequence, :ED)]
    # The model's clock is back on the simulation's initial time.
    @test PSI.get_initial_time(model) == t0
end

@testset "Test model export at each solve" begin
    # 2 simulation steps. Each format writes a single file per solve, so the
    # export directory holds exactly 2 files of the selected extension and none
    # of the other.
    for (fmt, ext, other_ext) in (
        (PSI.OptimizationModelExportFormat.LP, ".lp", ".json"),
        (PSI.OptimizationModelExportFormat.MOF, ".json", ".lp"),
    )
        folder = test_single_stage_sequential(true, false, fmt)
        test_path =
            joinpath(folder, "consecutive", "problems", "ED", "optimization_model_exports")
        @test ispath(test_path)
        files = readdir(test_path)
        @test length(files) == 2
        @test all(endswith(f, ext) for f in files)
        @test !any(endswith(f, other_ext) for f in files)
    end
end

function test_2_stage_decision_models_with_feedforwards(in_memory)
    template_uc = get_template_basic_uc_simulation()
    template_ed = get_template_nomin_ed_simulation()
    set_device_model!(template_ed, InterruptiblePowerLoad, StaticPowerLoad)
    set_network_model!(
        template_uc,
        NetworkModel(
            CopperPlateNetworkModel;
            duals = [CopperPlateBalanceConstraint],
        ),
    )
    set_network_model!(
        template_ed,
        NetworkModel(
            CopperPlateNetworkModel;
            duals = [CopperPlateBalanceConstraint],
            use_slacks = true,
        ),
    )
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                c_sys5_hy_uc;
                name = "UC",
                optimizer = HiGHS_optimizer),
            DecisionModel(
                template_ed,
                c_sys5_hy_ed;
                name = "ED",
                optimizer = HiGHS_optimizer,
            ),
        ],
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
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(;
        name = "no_cache",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )

    build_out = build!(sim; console_level = Logging.Error)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim; in_memory = in_memory)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end

@testset "2-Stage Decision Models with FeedForwards" begin
    for in_memory in (true, false)
        test_2_stage_decision_models_with_feedforwards(in_memory)
    end
end

@testset "Test Simulation Utils" begin
    template_uc = get_template_basic_uc_simulation()
    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_network_model!(
        template_uc,
        NetworkModel(
            CopperPlateNetworkModel;
            duals = [CopperPlateBalanceConstraint],
        ),
    )

    template_ed = get_template_nomin_ed_simulation(
        NetworkModel(
            CopperPlateNetworkModel;
            # Added because of data issues
            use_slacks = true,
            duals = [CopperPlateBalanceConstraint],
        ),
    )
    set_device_model!(template_ed, InterruptiblePowerLoad, StaticPowerLoad)
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                c_sys5_hy_uc;
                name = "UC",
                optimizer = HiGHS_optimizer,
            ),
            DecisionModel(
                template_ed,
                c_sys5_hy_ed;
                name = "ED",
                optimizer = HiGHS_optimizer,
            ),
        ],
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
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(;
        name = "aggregation",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = false),
    )

    build_out = build!(sim; console_level = Logging.Error)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    @testset "Verify simulation events" begin
        file = joinpath(PSI.get_simulation_dir(sim), "recorder", "simulation_status.log")
        @test isfile(file)
        sim_dir = PSI.get_simulation_dir(sim)
        for step in 1:2
            events = PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                sim_dir;
                step = step,
            )
            @test !isempty(events)
            @test all(x -> !isempty(x.device_names), events)
        end
        # The first UC execution keeps the initial conditions from the system data.
        @test isempty(
            PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                sim_dir;
                step = 1,
                model_name = "UC",
            ),
        )
        events = PSI.list_simulation_events(
            PSI.InitialConditionUpdateEvent,
            sim_dir;
            step = 2,
            model_name = "UC",
        )
        @test !isempty(events)
        @test all(x -> x.model_name == :UC, events)
        PSI.show_simulation_events(
            devnull,
            PSI.InitialConditionUpdateEvent,
            sim_dir;
            step = 2,
            model_name = "UC",
        )
    end
end

@testset "Test simulation with OnlineReserve" begin
    template_uc = get_template_basic_uc_simulation()
    set_network_model!(template_uc, NetworkModel(PTDFNetworkModel; use_slacks = true))
    set_device_model!(template_uc, DeviceModel(Line, StaticBranchUnbounded))
    # POM's `ServiceModel` keys all reserves of a type into ONE simulation-state entry
    # (a name axis inside the container, not one key per named reserve as PSI's old
    # per-instance `VariableReserve` keying did). `c_sys5_uc`'s `add_reserves=true` fixture
    # carries an extra "ORDC1" reserve that `c_sys5_ed`'s fixture does not, so without this
    # filter the UC-sized decision state would demand an "ORDC1" column that ED's own
    # solved results never populate. Filter UC down to the reserve roster the two systems
    # share so the cross-model state stays consistent.
    set_service_model!(
        template_uc,
        ServiceModel(
            OnlineReserve{ReserveUp},
            RangeReserve;
            attributes = Dict{String, Any}(
                "filter_function" => x -> PSY.get_name(x) != "ORDC1",
            ),
        ),
    )
    template_ed =
        get_template_nomin_ed_simulation(NetworkModel(PTDFNetworkModel; use_slacks = true))
    set_device_model!(template_ed, DeviceModel(Line, StaticBranchUnbounded))
    set_service_model!(template_ed, ServiceModel(OnlineReserve{ReserveUp}, RangeReserve))
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_reserves = true)
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_ed"; add_reserves = true)
    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                c_sys5_hy_uc;
                name = "UC",
                optimizer = HiGHS_optimizer,
                initialize_model = false,
            ),
            DecisionModel(
                template_ed,
                c_sys5_hy_ed;
                name = "ED",
                optimizer = HiGHS_optimizer,
                initialize_model = false,
            ),
        ],
    )

    # `attach_feedforward!(::ServiceModel, ...)` unconditionally errors: the feedforward
    # parameter path is keyed `(device_name, time)`, not the service-keyed
    # `(service_name, device_name, time)` POM's `ServiceModel` reserve variables use.
    # Coverage here is narrowed to the ThermalStandard feedforward; re-add the reserve
    # feedforward once POM implements service-keyed feedforward parameters.
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
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(;
        name = "reserve_feedforward",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    build_out = build!(sim)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    results = SimulationResults(sim)
    for name in list_decision_problems(results)
        res = get_decision_problem_results(results, name)
        parameters = read_realized_parameters(res)
        @test !isempty(parameters)
        for (key, df1) in parameters
            df2 = read_realized_parameter(res, key)
            @test df1 == df2
        end
    end
end

function test_3_stage_simulation_with_feedforwards(in_memory)
    sys_rts_da = PSB.build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    sys_rts_rt = PSB.build_system(PSISystems, "modified_RTS_GMLC_RT_sys")
    sys_rts_ha = deepcopy(sys_rts_rt)

    PSY.transform_single_time_series!(sys_rts_da, Hour(36), Hour(24))
    PSY.transform_single_time_series!(sys_rts_ha, Hour(2), Hour(1))
    PSY.transform_single_time_series!(sys_rts_rt, Hour(1), Hour(1))

    template_uc = get_template_standard_uc_simulation()
    set_network_model!(template_uc, NetworkModel(CopperPlateNetworkModel))
    template_ha = deepcopy(template_uc)
    # network slacks added because of data issues
    template_ed = get_thermal_dispatch_template_network(
        NetworkModel(CopperPlateNetworkModel; use_slacks = true),
    )

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                sys_rts_da;
                name = "UC",
                optimizer = HiGHS_optimizer,
                initialize_model = true,
            ),
            DecisionModel(
                template_ha,
                sys_rts_ha;
                name = "HA",
                optimizer = HiGHS_optimizer,
                initialize_model = true,
            ),
            DecisionModel(
                template_ed,
                sys_rts_rt;
                name = "ED",
                optimizer = HiGHS_optimizer,
                initialize_model = true,
            ),
        ],
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
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(;
        name = "3stage_feedforward",
        steps = 1,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    build_out = build!(sim)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim; in_memory = in_memory)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end

@testset "Test 3 stage simulation with FeedForwards" begin
    for in_memory in (true, false)
        test_3_stage_simulation_with_feedforwards(in_memory)
    end
end

function test_2_stage_fix_value_feedforward(in_memory)
    template_uc = get_template_basic_uc_simulation()
    template_ed = get_template_nomin_ed_simulation()
    set_device_model!(template_ed, ThermalStandard, ThermalBasicUnitCommitment)
    set_network_model!(
        template_ed,
        NetworkModel(CopperPlateNetworkModel; use_slacks = true),
    )
    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                PSB.build_system(PSITestSystems, "c_sys5_hy_uc");
                name = "UC",
                optimizer = HiGHS_optimizer,
            ),
            DecisionModel(
                template_ed,
                PSB.build_system(PSITestSystems, "c_sys5_hy_ed");
                name = "ED",
                optimizer = HiGHS_optimizer,
            ),
        ],
    )
    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
            "ED" => [
                FixValueFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [OnVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(;
        name = "fix_value_ff",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    @test build!(sim; console_level = Logging.Error) == PSI.SimulationBuildStatus.BUILT
    @test execute!(sim; in_memory = in_memory) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    results = SimulationResults(sim)
    on_uc = read_realized_variable(
        get_decision_problem_results(results, "UC"),
        "OnVariable__ThermalStandard",
    )
    on_ed = read_realized_variable(
        get_decision_problem_results(results, "ED"),
        "OnVariable__ThermalStandard",
    )
    # Each ED commitment is fixed to the UC commitment of the hour it falls in.
    on_ed.hour = floor.(on_ed.DateTime, Hour)
    joined = innerjoin(
        on_ed,
        on_uc;
        on = [:hour => :DateTime, :name],
        renamecols = "_ed" => "_uc",
    )
    @test nrow(joined) == nrow(on_ed)
    @test joined.value_ed ≈ joined.value_uc
end

function _fix_value_feedforward_simulation(steps; rebuild_model = false)
    template_uc = get_template_basic_uc_simulation()
    template_ed = get_template_nomin_ed_simulation()
    set_device_model!(template_ed, ThermalStandard, ThermalBasicUnitCommitment)
    set_network_model!(
        template_ed,
        NetworkModel(CopperPlateNetworkModel; use_slacks = true),
    )
    models = SimulationModels(;
        decision_models = [
            DecisionModel(template_uc, PSB.build_system(PSITestSystems, "c_sys5_hy_uc");
                name = "UC", optimizer = HiGHS_optimizer, rebuild_model = rebuild_model,
            ),
            DecisionModel(template_ed, PSB.build_system(PSITestSystems, "c_sys5_hy_ed");
                name = "ED", optimizer = HiGHS_optimizer, rebuild_model = rebuild_model,
            ),
        ],
    )
    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
            "ED" => [
                FixValueFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [OnVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    return Simulation(;
        name = "release_models",
        steps = steps,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
end

function _realized_variables(sim, model_names)
    results = SimulationResults(sim)
    values = Dict{String, DataFrame}()
    for name in model_names
        problem_results = get_decision_problem_results(results, name)
        for key in list_variable_names(problem_results)
            df = read_realized_variable(problem_results, key)
            values["$(name)/$(key)"] = sort(df, names(df))
        end
    end
    return values
end

@testset "Released models leave the simulation results unchanged" begin
    # A rebuilt model is released after every execution, the others after their last one.
    for rebuild_model in (false, true), in_memory in (true, false)
        kept = _fix_value_feedforward_simulation(2; rebuild_model = rebuild_model)
        @test build!(kept; console_level = Logging.Error) ==
              PSI.SimulationBuildStatus.BUILT
        @test execute!(kept; in_memory = in_memory) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

        released = _fix_value_feedforward_simulation(2; rebuild_model = rebuild_model)
        @test build!(released; console_level = Logging.Error) ==
              PSI.SimulationBuildStatus.BUILT
        @test execute!(released; in_memory = in_memory, release_models = true) ==
              PSI.RunStatus.SUCCESSFULLY_FINALIZED

        @test _realized_variables(released, ("UC", "ED")) ==
              _realized_variables(kept, ("UC", "ED"))
        for model in PSI.get_decision_models(PSI.get_models(released))
            container = IOM.get_optimization_container(model)
            @test JuMP.num_variables(IOM.get_jump_model(container)) == 0
            @test isempty(IOM.get_variables(container))
            @test isempty(IOM.get_parameters(container))
        end
        for model in PSI.get_decision_models(PSI.get_models(kept))
            @test JuMP.num_variables(IOM.get_jump_model(model)) > 0
        end
    end
end

# A day-ahead unit commitment that does not model Alta feeds its commitment forward into a
# unit commitment over every unit.
function _subset_source_simulation(feedforward; rebuild_model = false)
    sys_da = PSB.build_system(PSITestSystems, "c_sys5_uc"; force_build = true)
    sys_ru = PSB.build_system(PSITestSystems, "c_sys5_uc"; force_build = true)
    set_available!(get_component(ThermalStandard, sys_da, "Alta"), false)
    models = SimulationModels(;
        decision_models = [
            DecisionModel(get_template_basic_uc_simulation(), sys_da;
                name = "DA", optimizer = HiGHS_optimizer),
            DecisionModel(get_template_basic_uc_simulation(), sys_ru;
                name = "RU", optimizer = HiGHS_optimizer, rebuild_model = rebuild_model,
            ),
        ],
    )
    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
            "RU" => [
                feedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [OnVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    return Simulation(;
        name = "subset_source",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
end

@testset "A feedforward applies only to the components its source model has" begin
    for (feedforward, constraint, holds) in (
            (FixValueFeedforward, POM.FeedforwardFixValueConstraint, ==),
            (LowerBoundFeedforward, POM.FeedforwardLowerBoundConstraint, >=),
            (UpperBoundFeedforward, POM.FeedforwardUpperBoundConstraint, <=),
        ),
        rebuild_model in (false, true)

        sim = _subset_source_simulation(feedforward; rebuild_model = rebuild_model)
        @test build!(sim; console_level = Logging.Error) == PSI.SimulationBuildStatus.BUILT
        ru = PSI.get_simulation_model(PSI.get_models(sim), :RU)
        container = IOM.get_optimization_container(ru)
        rows() = only(
            v for (k, v) in IOM.get_constraints(container) if
            IOM.get_entry_type(k) === constraint
        )
        @test !("Alta" in axes(rows())[1])
        @test "Park City" in axes(rows())[1]
        @test execute!(sim; in_memory = true) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
        # The model solved last after its rebuild at the second step, if it was rebuilt.
        @test !("Alta" in axes(rows())[1])

        values = _realized_variables(sim, ("DA", "RU"))
        da = values["DA/OnVariable__ThermalStandard"]
        ru_on = values["RU/OnVariable__ThermalStandard"]
        @test "Alta" in ru_on.name
        joined = innerjoin(da, ru_on; on = [:DateTime, :name], renamecols = "_da" => "_ru")
        @test nrow(joined) == nrow(da)
        @test all(holds.(joined.value_ru, joined.value_da))
    end
end

# A unit commitment that does not model Alta holds the dispatch of the units it commits.
function _subset_source_semicontinuous_simulation(; rebuild_model = false)
    sys_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc"; force_build = true)
    sys_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed"; force_build = true)
    set_available!(get_component(ThermalStandard, sys_uc, "Alta"), false)
    template_ed = get_template_nomin_ed_simulation(
        NetworkModel(CopperPlateNetworkModel; use_slacks = true),
    )
    set_device_model!(template_ed, ThermalStandard, ThermalBasicDispatch)
    models = SimulationModels(;
        decision_models = [
            DecisionModel(get_template_basic_uc_simulation(), sys_uc;
                name = "UC", optimizer = HiGHS_optimizer),
            DecisionModel(template_ed, sys_ed;
                name = "ED", optimizer = HiGHS_optimizer, rebuild_model = rebuild_model,
            ),
        ],
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
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    return Simulation(;
        name = "subset_source_semicontinuous",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
end

@testset "A semicontinuous feedforward leaves the units its source lacks to the formulation" begin
    for rebuild_model in (false, true)
        sim = _subset_source_semicontinuous_simulation(; rebuild_model = rebuild_model)
        @test build!(sim; console_level = Logging.Error) == PSI.SimulationBuildStatus.BUILT
        ed = PSI.get_simulation_model(PSI.get_models(sim), :ED)
        container = IOM.get_optimization_container(ed)
        names(constraint) = union((
            Set(axes(v)[1]) for (k, v) in IOM.get_constraints(container) if
            IOM.get_entry_type(k) === constraint &&
            IOM.get_component_type(k) === ThermalStandard
        )...)
        check_rows() = begin
            @test !("Alta" in names(POM.FeedforwardSemiContinuousConstraint))
            @test "Park City" in names(POM.FeedforwardSemiContinuousConstraint)
            @test names(POM.ActivePowerVariableLimitsConstraint) == Set(["Alta"])
            @test !("Alta" in axes(
                IOM.get_parameter_array(container, POM.OnStatusParameter, ThermalStandard),
            )[1])
        end
        check_rows()
        @test execute!(sim; in_memory = true) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
        check_rows()

        values = _realized_variables(sim, ("UC", "ED"))
        on = values["UC/OnVariable__ThermalStandard"]
        power = values["ED/ActivePowerVariable__ThermalStandard"]
        @test "Alta" in power.name
        status = Dict((r.DateTime, r.name) => r.value for r in eachrow(on))
        off = [
            r.value for r in eachrow(power) if
            get(status, (floor(r.DateTime, Dates.Hour), r.name), 1.0) < 0.5
        ]
        @test !isempty(off)
        @test all(abs.(off) .<= 1e-6)
    end
end

@testset "2-Stage Decision Models with FixValueFeedforward" begin
    for in_memory in (true, false)
        test_2_stage_fix_value_feedforward(in_memory)
    end
end
