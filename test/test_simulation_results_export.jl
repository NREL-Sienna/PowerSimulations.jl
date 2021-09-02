
import PowerSimulations:
    SimulationStoreParams,
    ModelStoreParams,
    get_problem_exports,
    should_export_dual,
    should_export_parameter,
    should_export_variable,
    OptimizationContainerMetadata

function _make_params()
    sim = Dict(
        "initial_time" => Dates.DateTime("2020-01-01T00:00:00"),
        "step_resolution" => Dates.Hour(24),
        "num_steps" => 2,
    )
    problem_defs = OrderedDict(
        :ED => Dict(
            "execution_count" => 24,
            "horizon" => 12,
            "interval" => Dates.Hour(1),
            "resolution" => Dates.Hour(1),
            "end_of_interval_step" => 12,
            "base_power" => 100.0,
            "system_uuid" => Base.UUID("4076af6c-e467-56ae-b986-b466b2749572"),
        ),
        :UC => Dict(
            "execution_count" => 1,
            "horizon" => 24,
            "interval" => Dates.Hour(1),
            "resolution" => Dates.Hour(24),
            "end_of_interval_step" => 1,
            "base_power" => 100.0,
            "system_uuid" => Base.UUID("4076af6c-e467-56ae-b986-b466b2749572"),
        ),
    )
    container_metadata = OptimizationContainerMetadata(
        Dict(
            "ActivePowerVariable_ThermalStandard" =>
                PSI.VariableKey(ActivePowerVariable, ThermalStandard),
            "EnergyVariable_HydroEnergyReservoir" =>
                PSI.VariableKey(EnergyVariable, HydroEnergyReservoir),
            "OnVariable_ThermalStandard" =>
                PSI.VariableKey(OnVariable, ThermalStandard),
        ),
    )
    problems = OrderedDict{Symbol, ModelStoreParams}()
    for problem in keys(problem_defs)
        problem_params = ModelStoreParams(
            problem_defs[problem]["execution_count"],
            problem_defs[problem]["horizon"],
            problem_defs[problem]["interval"],
            problem_defs[problem]["resolution"],
            problem_defs[problem]["end_of_interval_step"],
            problem_defs[problem]["base_power"],
            problem_defs[problem]["system_uuid"],
            container_metadata,
        )

        problems[problem] = problem_params
    end

    return SimulationStoreParams(
        sim["initial_time"],
        sim["step_resolution"],
        sim["num_steps"],
        problems,
    )
end

@testset "Test export from JSON" begin
    params = _make_params()
    exports = SimulationResultsExport(joinpath(DATA_DIR, "results_export.json"), params)

    valid = Dates.DateTime("2020-01-01T06:00:00")
    valid2 = Dates.DateTime("2020-01-02T23:00:00")
    invalid = Dates.DateTime("2020-01-01T02:00:00")
    invalid2 = Dates.DateTime("2020-01-03T00:00:00")

    @test should_export_variable(
        exports,
        valid,
        :ED,
        PSI.VariableKey(ActivePowerVariable, ThermalStandard),
    )
    @test should_export_variable(
        exports,
        valid2,
        :ED,
        PSI.VariableKey(ActivePowerVariable, ThermalStandard),
    )
    @test !should_export_variable(
        exports,
        invalid,
        :ED,
        PSI.VariableKey(ActivePowerVariable, ThermalStandard),
    )
    @test !should_export_variable(
        exports,
        invalid2,
        :ED,
        PSI.VariableKey(ActivePowerVariable, ThermalStandard),
    )
    @test !should_export_variable(
        exports,
        valid,
        :ED,
        PSI.VariableKey(ActivePowerVariable, RenewableFix),
    )
    @test should_export_parameter(
        exports,
        valid,
        :ED,
        PSI.ParameterKey(ActivePowerTimeSeriesParameter, ThermalStandard),
    )
    @test !should_export_dual(
        exports,
        valid,
        :ED,
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, RenewableFix),
    )

    @test should_export_variable(
        exports,
        valid,
        :UC,
        PSI.VariableKey(OnVariable, ThermalStandard),
    )
    @test !should_export_variable(
        exports,
        valid,
        :UC,
        PSI.VariableKey(ActivePowerVariable, RenewableFix),
    )
    @test should_export_parameter(
        exports,
        valid,
        :UC,
        PSI.ParameterKey(ActivePowerTimeSeriesParameter, ThermalStandard),
    )
    @test should_export_dual(
        exports,
        valid,
        :UC,
        PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, RenewableFix),
    )

    @test exports.path == "export_path"
    @test exports.format == "csv"
    @test "csv" in list_supported_formats(SimulationResultsExport)
end

@testset "Invalid exports" begin
    params = _make_params()
    valid = Dates.DateTime("2020-01-01T00:00:00")
    invalid = Dates.DateTime("2020-01-03T00:00:00")

    # Invalid start_time
    @test_throws IS.InvalidValue SimulationResultsExport(
        Dict("start_time" => invalid, "models" => [Dict("name" => "ED")]),
        params,
    )

    # Invalid end_time
    @test_throws IS.InvalidValue SimulationResultsExport(
        Dict("end_time" => invalid, "models" => [Dict("name" => "ED")]),
        params,
    )

    # Invalid format
    @test_throws IS.InvalidValue SimulationResultsExport(
        Dict("format" => "invalid", "models" => [Dict("name" => "ED")]),
        params,
    )

    # Missing name
    @test_throws IS.InvalidValue SimulationResultsExport(
        Dict("models" => [Dict("variables" => ["ActivePowerVariable_ThermalStandard"])]),
        params,
    )
end
