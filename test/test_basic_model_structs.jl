@testset "DeviceModel Tests" begin
    @test_throws ArgumentError DeviceModel(ThermalGen, ThermalStandardUnitCommitment)
    @test_throws ArgumentError DeviceModel(ThermalStandard, PSI.AbstractThermalFormulation)
    @test_throws ArgumentError NetworkModel(PM.AbstractPowerModel)
end

@testset "NetworkModel Tests" begin
    @test_throws ArgumentError NetworkModel(PM.AbstractPowerModel)
end

@testset "ServiceModel Tests" begin
    @test_throws ArgumentError ServiceModel(AGC, PSI.AbstractAGCFormulation, "TestName")
    @test_throws ArgumentError ServiceModel(
        VariableReserve{PSY.ReserveUp},
        PSI.AbstractReservesFormulation,
        "TestName2",
    )
end

@testset "Feedforward Struct Tests" begin
    ffs = [
        UpperBoundFeedforward(;
            component_type = RenewableDispatch,
            source = ActivePowerVariable,
            affected_values = [ActivePowerVariable],
            add_slacks = true,
        ),
        LowerBoundFeedforward(;
            component_type = RenewableDispatch,
            source = ActivePowerVariable,
            affected_values = [ActivePowerVariable],
            add_slacks = true,
        ),
        SemiContinuousFeedforward(;
            component_type = ThermalMultiStart,
            source = OnVariable,
            affected_values = [ActivePowerVariable, ReactivePowerVariable],
        ),
    ]

    for ff in ffs
        for av in PSI.get_affected_values(ff)
            @test isa(av, PSI.IS.VariableKey)
        end
    end

    ff = FixValueFeedforward(;
        component_type = HydroDispatch,
        source = OnVariable,
        affected_values = [OnStatusParameter],
    )

    for av in PSI.get_affected_values(ff)
        @test isa(av, PSI.IS.ParameterKey)
    end

    @test_throws ErrorException UpperBoundFeedforward(
        component_type = RenewableDispatch,
        source = ActivePowerVariable,
        affected_values = [OnStatusParameter],
        add_slacks = true,
    )

    @test_throws ErrorException LowerBoundFeedforward(
        component_type = RenewableDispatch,
        source = ActivePowerVariable,
        affected_values = [OnStatusParameter],
        add_slacks = true,
    )

    @test_throws ErrorException SemiContinuousFeedforward(
        component_type = ThermalMultiStart,
        source = OnVariable,
        affected_values = [ActivePowerVariable, OnStatusParameter],
    )
end
