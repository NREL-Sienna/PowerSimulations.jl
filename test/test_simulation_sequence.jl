@testset "Simulation Sequence Correct Execution Order" begin
    models = SimulationModels(
        [
            DecisionModel(
                MockOperationProblem;
                horizon = 48,
                interval = Hour(24),
                steps = 2,
                name = "DAUC",
            ),
            DecisionModel(
                MockOperationProblem;
                horizon = 24,
                interval = Hour(1),
                steps = 2 * 24,
                name = "HAUC",
            ),
            DecisionModel(
                MockOperationProblem;
                horizon = 12,
                interval = Minute(5),
                steps = 2 * 24 * 12,
                name = "ED",
            ),
        ],
        EmulationModel(MockEmulationProblem; resolution = Minute(1), name = "AGC"),
    )

    test_sequence =
        SimulationSequence(models = models, feedforwards = Dict(
            "ED" => SemiContinuousFeedforward(
                component_type = ThermalStandard,
                source = OnVariable,
                affected_values = [ActivePowerVariable],
            ),
        ), ini_cond_chronology = InterProblemChronology())

    @test length(findall(x -> x == 4, test_sequence.execution_order)) == 24 * 60
    @test length(findall(x -> x == 3, test_sequence.execution_order)) == 24 * 12
    @test length(findall(x -> x == 2, test_sequence.execution_order)) == 24
    @test length(findall(x -> x == 1, test_sequence.execution_order)) == 1

    for model in PSI.get_decision_models(models)
        @test model.internal.simulation_info.sequence_uuid == test_sequence.uuid
    end

    # Test single stage sequence
    test_sequence = SimulationSequence(
        models = SimulationModels(
        # TODO: support passing one model without making a vector
        [DecisionModel(MockOperationProblem; horizon = 48, name = "DAUC")]),
        ini_cond_chronology = InterProblemChronology(),
    )

    @test isa(test_sequence.ini_cond_chronology, IntraProblemChronology)
    @test test_sequence.execution_order == [1]
end

@testset "Simulation Sequence invalid sequences" begin
    models = SimulationModels(
        [
            DecisionModel(
                MockOperationProblem;
                horizon = 48,
                interval = Hour(24),
                steps = 2,
                name = "DAUC",
            ),
            DecisionModel(
                MockOperationProblem;
                horizon = 24,
                interval = Hour(5),
                steps = 2 * 24,
                name = "HAUC",
            ),]
    )

    @test_throws IS.ConflictingInputsError SimulationSequence(models = models)

    models = SimulationModels(
        [
            DecisionModel(
                MockOperationProblem;
                horizon = 2,
                interval = Hour(1),
                steps = 2,
                name = "DAUC",
            ),
            DecisionModel(
                MockOperationProblem;
                horizon = 24,
                interval = Hour(1),
                steps = 2 * 24,
                name = "HAUC",
            ),]
    )

    @test_throws IS.ConflictingInputsError SimulationSequence(models = models)

    models = SimulationModels(
        [
            DecisionModel(
                MockOperationProblem;
                horizon = 24,
                interval = Hour(1),
                steps = 2,
                name = "DAUC",
            ),
            DecisionModel(
                MockOperationProblem;
                horizon = 24,
                interval = Minute(22),
                steps = 2 * 24,
                name = "HAUC",
            ),]
    )

    @test_throws IS.ConflictingInputsError SimulationSequence(models = models)
end
