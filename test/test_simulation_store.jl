import PowerSimulations:
    h5_store_open,
    HDF_FILENAME,
    SimulationStoreParams,
    SimulationStoreProblemParams,
    SimulationStoreProblemRequirements,
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
    stages = OrderedDict{Symbol, SimulationStoreProblemParams}()
    stage_reqs = Dict{Symbol, SimulationStoreProblemRequirements}()
    num_param_containers = 0
    for stage in keys(stage_defs)
        execution_count = stage_defs[stage]["execution_count"]
        horizon = stage_defs[stage]["horizon"]
        num_rows = execution_count * sim["num_steps"]

        stage_params = SimulationStoreProblemParams(
            execution_count,
            horizon,
            stage_defs[stage]["interval"],
            stage_defs[stage]["resolution"],
            stage_defs[stage]["end_of_interval_step"],
            stage_defs[stage]["base_power"],
            stage_defs[stage]["system_uuid"],
        )
        reqs = SimulationStoreProblemRequirements()

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
    h5_store_open(path, "w") do store
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
    h5_store_open(path, "r") do store
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
        :P__ThermalStandard =>
            Dict("cache_priority" => CachePriority.HIGH, "keep_in_cache" => true),
        :P__InterruptibleLoad =>
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
            "base_power" => 100.0,
            "system_uuid" => Base.UUID("4076af6c-e467-56ae-b986-b466b2749572"),
        ),
    )
    cache_rules = CacheFlushRules(max_size = 1 * MiB, min_flush_size = 4 * KiB)

    path = mktempdir()
    # Use this seed to produce the same randomly generated arrays for write and verify.
    seed = 1234
    _run_sim_test(path, sim, variables, stage_defs, cache_rules, seed)
    _verify_read_results(path, sim, variables, stage_defs, seed)
end

# TODO: test optimizer stats
# TODO: unit tests of individual functions, size checks
# TODO: 3-d arrays
# TODO: profiling of memory performance and GC
