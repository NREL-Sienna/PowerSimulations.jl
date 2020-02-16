@testset "Simulation Sequence" begin
    feedforward_chronologies = Dict(
        ("UC" => "HAUC") => Synchronize(periods = 24),
        ("HAUC" => "ED") => RecedingHorizon(),
        ("ED" => "AGC") => RecedingHorizon(),
    )
    ini_cond_chronology = InterStageChronology()
    order = Dict(1 => "DAUC", 2 => "HAUC", 3 => "ED", 4 => "AGC")
    intervals = Dict(
        "DAUC" => (Hour(24), Consecutive()),
        "HAUC" => (Hour(1), RecedingHorizon()),
        "ED" => (Minute(5), RecedingHorizon()),
        "AGC" => (Minute(1), Consecutive()),
    )
    horizons = Dict("DAUC" => 48, "HAUC" => 24, "ED" => 12, "AGC" => 6)

    test_sequence = SimulationSequence(
        order = order,
        feedforward_chronologies = feedforward_chronologies,
        step_resolution = Hour(24),
        horizons = horizons,
        intervals = intervals,
        ini_cond_chronology = ini_cond_chronology,
    )

    @test length(findall(x -> x == 4, test_sequence.execution_order)) == 24 * 60
    @test length(findall(x -> x == 3, test_sequence.execution_order)) == 24 * 12
    @test length(findall(x -> x == 2, test_sequence.execution_order)) == 24
    @test length(findall(x -> x == 1, test_sequence.execution_order)) == 1

    bad_order = Dict(1 => "DAUC", 5 => "HAUC", 3 => "ED", 4 => "AGC")
    @test_throws IS.InvalidValue SimulationSequence(
        order = bad_order,
        feedforward_chronologies = feedforward_chronologies,
        step_resolution = Hour(24),
        horizons = horizons,
        intervals = intervals,
        ini_cond_chronology = ini_cond_chronology,
    )

    @test_throws ArgumentError SimulationSequence(
        step_resolution = Hour(24),
        order = Dict(1 => "UC", 2 => "ED"),
        horizons = Dict("UC" => 24, "ED" => 12),
        intervals = Dict(
            "UC" => (Hour(24), Consecutive()),
            "ED" => (Hour(1), Consecutive()),
        ),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_from_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        cache = Dict("ED" => [TimeStatusChange(PSY.ThermalStandard, PSI.ON)]),
        ini_cond_chronology = InterStageChronology(),
    )

    test_sequence = SimulationSequence(
        order = Dict(1 => "DAUC"),
        step_resolution = Hour(24),
        horizons = Dict("DAUC" => 24),
        intervals = Dict("DAUC" => (Hour(24), Consecutive())),
        ini_cond_chronology = InterStageChronology(),
    )

    @test isa(test_sequence.ini_cond_chronology, IntraStageChronology)
    @test test_sequence.execution_order == [1]

end

@testset "testing if Horizon and interval result in a discontinuous simulation" begin
    @test_throws IS.ConflictingInputsError SimulationSequence(
        step_resolution = Hour(24),
        order = Dict(1 => "UC", 2 => "ED"),
        feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
        horizons = Dict("UC" => 24, "ED" => 12),
        intervals = Dict(
            "UC" => (Hour(2), Consecutive()),
            "ED" => (Hour(3), RecedingHorizon()),
        ),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_from_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        cache = Dict("ED" => [TimeStatusChange(PSY.ThermalStandard, PSI.ON)]),
        ini_cond_chronology = InterStageChronology(),
    )
end
