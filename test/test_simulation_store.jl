import PowerSimulations:
    open_store,
    HdfSimulationStore,
    HDF_FILENAME,
    SimulationStoreParams,
    ModelStoreParams,
    StoreModelRequirements,
    CacheFlushRules,
    KiB,
    MiB,
    GiB,
    STORE_CONTAINER_VARIABLES,
    CachePriority,
    initialize_problem_storage!,
    add_rule!,
    write_result!,
    read_result,
    has_dirty,
    get_cache_hit_percentage

function _initialize!(store, sim, variables, stage_defs, cache_rules)
    stages = OrderedDict{Symbol, ModelStoreParams}()
    stage_reqs = Dict{Symbol, StoreModelRequirements}()
    num_param_containers = 0
    for stage in keys(stage_defs)
        execution_count = stage_defs[stage]["execution_count"]
        horizon = stage_defs[stage]["horizon"]
        num_rows = execution_count * sim["num_steps"]

        stage_params = ModelStoreParams(
            execution_count,
            horizon,
            stage_defs[stage]["interval"],
            stage_defs[stage]["resolution"],
            stage_defs[stage]["end_of_interval_step"],
            stage_defs[stage]["base_power"],
            stage_defs[stage]["system_uuid"],
        )
        reqs = StoreModelRequirements()

        for (name, array) in stage_defs[stage]["variables"]
            reqs.variables[name] = Dict(
                "columns" => stage_defs[stage]["names"],
                "dims" => (horizon, length(stage_defs[stage]["names"]), num_rows),
            )
            keep_in_cache = variables[name]["keep_in_cache"]
            cache_priority = variables[name]["cache_priority"]
            add_rule!(
                cache_rules,
                stage,
                STORE_CONTAINER_VARIABLES,
                name,
                keep_in_cache,
                cache_priority,
            )
        end

        stages[stage] = stage_params
        stage_reqs[stage] = reqs
        num_param_containers += length(reqs.variables)
    end

    params = SimulationStoreParams(
        sim["initial_time"],
        sim["step_resolution"],
        sim["num_steps"],
        stages,
    )
    initialize_problem_storage!(store, params, stage_reqs, cache_rules)
end

function _run_sim_test(path, sim, variables, stage_defs, cache_rules, seed)
    rng = MersenneTwister(seed)
    type = STORE_CONTAINER_VARIABLES
    open_store(HdfSimulationStore, path, "w") do store
        sim_time = sim["initial_time"]
        _initialize!(store, sim, variables, stage_defs, cache_rules)
        for step in 1:sim["num_steps"]
            for stage in keys(stage_defs)
                stage_time = sim_time
                for i in 1:stage_defs[stage]["execution_count"]
                    for name in keys(variables)
                        data = rand(rng, size(stage_defs[stage]["variables"][name])...)
                        write_result!(store, stage, type, name, stage_time, data)
                        columns = stage_defs[stage]["names"]
                        _verify_data(data, store, stage, type, name, stage_time, columns)
                    end

                    stage_time += stage_defs[stage]["resolution"]
                end
            end

            sim_time += sim["step_resolution"]
        end

        for param_cache in values(store.cache.data)
            @test get_cache_hit_percentage(param_cache) == 100.0
        end

        flush(store)
        @test !has_dirty(store.cache)
    end
end

function _verify_read_results(path, sim, variables, stage_defs, seed)
    rng = MersenneTwister(seed)
    type = STORE_CONTAINER_VARIABLES
    open_store(HdfSimulationStore, path, "r") do store
        sim_time = sim["initial_time"]
        for step in 1:sim["num_steps"]
            for stage in keys(stage_defs)
                stage_time = sim_time
                for i in 1:stage_defs[stage]["execution_count"]
                    for name in keys(variables)
                        data = rand(rng, size(stage_defs[stage]["variables"][name])...)
                        columns = stage_defs[stage]["names"]
                        _verify_data(data, store, stage, type, name, stage_time, columns)
                    end

                    stage_time += stage_defs[stage]["resolution"]
                end
            end

            sim_time += sim["step_resolution"]
        end

        for param_cache in values(store.cache.data)
            @test get_cache_hit_percentage(param_cache) == 0.0
        end
    end
end

function _verify_data(expected, store, stage, type, name, time, columns)
    expected_df = DataFrames.DataFrame(expected, columns)
    df = read_result(DataFrames.DataFrame, store, stage, type, name, time)
    @test expected_df == df

    # TODO read_result with JuMP.Containers.DenseAxisArray
end

@testset "Test SimulationStore 2-d arrays" begin
    sim = Dict(
        "initial_time" => Dates.DateTime("2020-01-01T00:00:00"),
        "step_resolution" => Dates.Hour(24),
        "num_steps" => 2,
    )
    variables = Dict(
        PSI.VariableKey(ActivePowerVariable, ThermalStandard) =>
            Dict("cache_priority" => CachePriority.HIGH, "keep_in_cache" => true),
        PSI.VariableKey(ActivePowerVariable, InterruptibleLoad) =>
            Dict("cache_priority" => CachePriority.LOW, "keep_in_cache" => false),
    )
    stage_defs = OrderedDict(
        :ED => Dict(
            "execution_count" => 24,
            "horizon" => 12,
            "names" => [:dev1, :dev2, :dev3, :dev4, :dev5],
            "variables" => Dict(x => ones(12, 5) for x in keys(variables)),
            "interval" => Dates.Hour(1),
            "resolution" => Dates.Hour(1),
            "end_of_interval_step" => 1,
            "base_power" => 100.0,
            "system_uuid" => Base.UUID("4076af6c-e467-56ae-b986-b466b2749572"),
        ),
        :UC => Dict(
            "execution_count" => 1,
            "horizon" => 24,
            "names" => [:dev1, :dev2, :dev3],
            "variables" => Dict(x => ones(24, 3) for x in keys(variables)),
            "interval" => Dates.Hour(1),
            "resolution" => Dates.Hour(24),
            "end_of_interval_step" => 12,
            "base_power" => 100.0,
            "system_uuid" => Base.UUID("4076af6c-e467-56ae-b986-b466b2749572"),
        ),
    )
    cache_rules = CacheFlushRules(max_size = 1 * MiB, min_flush_size = 4 * KiB)

    path = mktempdir()
    # Use this seed to produce the same randomly generated arrays for write and verify.
    seed = 1234
    _run_sim_test(path, sim, variables, stage_defs, cache_rules, seed)
    # TODO: Re-enable later when we serialize the keys to be deserialized later
    # _verify_read_results(path, sim, variables, stage_defs, seed)
end

@testset "Test ModelOutputCache" begin
    key = PSI.OutputCacheKey(:ED, PSI.VariableKey(ActivePowerVariable, InterruptibleLoad))
    cache = PSI.ModelOutputCache(key, PSI.CacheFlushRule())
    @test !PSI.has_clean(cache)
    @test !PSI.is_dirty(cache, Dates.now())

    timestamp1 = Dates.DateTime("2020-01-01T00:00:00")
    timestamp2 = Dates.DateTime("2020-01-01T01:00:00")
    timestamp3 = Dates.DateTime("2020-01-01T02:00:00")
    PSI.add_result!(cache, timestamp1, ones(2), false)
    @test PSI.is_dirty(cache, timestamp1)
    PSI.add_result!(cache, timestamp2, ones(2), false)
    @test PSI.is_dirty(cache, timestamp2)

    @test length(cache.data) == 2
    @test length(cache.dirty_timestamps) == 2

    popfirst!(cache.dirty_timestamps)
    @test !PSI.is_dirty(cache, timestamp1)
    @test PSI.has_clean(cache)
    PSI.add_result!(cache, timestamp3, ones(2), true)
    @test length(cache.data) == 2

    empty!(cache)
    @test isempty(cache.data)
    @test isempty(cache.dirty_timestamps)

    PSI.add_result!(cache, timestamp1, ones(2), false)
    PSI.add_result!(cache, timestamp2, ones(2), false)
    PSI.discard_results!(cache, [timestamp1, timestamp2])
    @test isempty(cache.data)
end

# TODO: test optimizer stats
# TODO: unit tests of individual functions, size checks
# TODO: 3-d arrays
# TODO: profiling of memory performance and GC
