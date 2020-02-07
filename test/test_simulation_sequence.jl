@testset "Simulation Sequence" begin
feedforward_chronologies = Dict(("UC" => "HAUC") => Synchronize(periods = 24),
                                ("HAUC" => "ED") => RecedingHorizon(),
                                ("ED" => "AGC") => RecedingHorizon())
ini_cond_chronology = InterStage()
order = Dict(1 => "DAUC", 2 => "HAUC", 3 => "ED", 4 => "AGC")
intervals = Dict("DAUC" => Hour(24), "HAUC" => Hour(1), "ED" => Minute(5), "AGC" => Minute(1))
horizons = Dict("DAUC" => 48, "HAUC" => 24, "ED" => 12, "AGC" => 6)

test_sequence = SimulationSequence(order = order,
                                     feedforward_chronologies = feedforward_chronologies,
                                     step_resolution = Hour(24),
                                     horizons = horizons,
                                     intervals = intervals,
                                     ini_cond_chronology = ini_cond_chronology)

    @test length(findall(x -> x == 4, test_sequence.execution_order)) == 24*60
    @test length(findall(x -> x == 3, test_sequence.execution_order)) == 24*12
    @test length(findall(x -> x == 2, test_sequence.execution_order)) == 24
    @test length(findall(x -> x == 1, test_sequence.execution_order)) == 1

    bad_order = Dict(1 => "DAUC", 5 => "HAUC", 3 => "ED", 4 => "AGC")
    @test_throws IS.InvalidValue     SimulationSequence(order = bad_order,
                                     feedforward_chronologies = feedforward_chronologies,
                                     step_resolution = Hour(24),
                                     horizons = horizons,
                                     intervals = intervals,
                                     ini_cond_chronology = ini_cond_chronology)
end
