@testset "DeviceModel Tests" begin
    @test_throws ArgumentError DeviceModel(ThermalGen, ThermalStandardUnitCommitment)
    @test_throws ArgumentError DeviceModel(ThermalStandard, PSI.AbstractThermalFormulation)
    @test_throws ArgumentError NetworkModel(PM.AbstractPowerModel)
end

@testset "NetworkModel Tests" begin
    @test_throws ArgumentError NetworkModel(PM.AbstractPowerModel)
end

@testset "ServiceModel Tests" begin
    @test_throws ArgumentError ServiceModel(AGC, PSI.AbstractServiceFormulation, "TestName")
    @test_throws ArgumentError ServiceModel(
        VariableReserve{PSY.ReserveUp},
        PSI.AbstractServiceFormulation,
        "TestName2",
    )
end

@testset "Feedforward Struct Tests" begin
    ffs = [
        UpperBoundFeedforward(
            component_type = RenewableDispatch,
            source = ActivePowerVariable,
            affected_values = [ActivePowerVariable],
        ),
        LowerBoundFeedforward(
            component_type = RenewableDispatch,
            source = ActivePowerVariable,
            affected_values = [ActivePowerVariable],
        ),
        SemiContinuousFeedforward(
            component_type = ThermalMultiStart,
            source = OnVariable,
            affected_values = [ActivePowerVariable, ReactivePowerVariable],
        ),
        IntegralLimitFeedforward(
            component_type = GenericBattery,
            source = EnergyVariable,
            affected_values = [EnergyVariable],
            number_of_periods = 10,
        ),
    ]

    for ff in ffs
        for av in PSI.get_affected_values(ff)
            @test isa(av, PSI.VariableKey)
        end
    end

    ff = FixValueFeedforward(
        component_type = HydroDispatch,
        source = OnVariable,
        affected_values = [OnStatusParameter],
    )

    for av in PSI.get_affected_values(ff)
        @test isa(av, PSI.ParameterKey)
    end

    @test_throws ErrorException IntegralLimitFeedforward(
        component_type = GenericBattery,
        source = EnergyVariable,
        affected_values = [OnStatusParameter],
        number_of_periods = 10,
    )

    @test_throws ErrorException UpperBoundFeedforward(
        component_type = RenewableDispatch,
        source = ActivePowerVariable,
        affected_values = [OnStatusParameter],
    )

    @test_throws ErrorException LowerBoundFeedforward(
        component_type = RenewableDispatch,
        source = ActivePowerVariable,
        affected_values = [OnStatusParameter],
    )

    @test_throws ErrorException SemiContinuousFeedforward(
        component_type = ThermalMultiStart,
        source = OnVariable,
        affected_values = [ActivePowerVariable, OnStatusParameter],
    )
end

@testset "SequentialWriteDataFrame Tests" begin
    df1 = PSI.SequentialWriteDataFrame(DataFrame(:a => ones(10)))
    @test isa(getfield(df1, :data), DataFrames.DataFrame)

    df2 = PSI.SequentialWriteDataFrame(:a => ones(10))
    @test isa(getfield(df1, :data), DataFrames.DataFrame)

    @test names(df2) == ["a"]

    df3 = mapcols(x -> 5 * x, df2)
    @test all(df3.a .== 5.0)

    @test ncol(df3) == 1
    @test nrow(df3) == 10

    df4 = PSI.SequentialWriteDataFrame(:a => ones(10), :b => ones(10), :c => ones(10))

    for i in 1:5
        PSI.set_next_rows!(df4, [10 10 10; 20 20 20])
        @test PSI.get_last_recorded_row(df4) == i * 2
    end

    df5 = PSI.SequentialWriteDataFrame(:a => ones(10), :b => ones(10), :c => ones(10))

    for i in 1:5
        PSI.set_next_rows!(df5, [20 20 20])
        @test PSI.get_last_recorded_row(df5) == i
    end

    df6 = PSI.SequentialWriteDataFrame(:a => ones(10), :b => ones(10), :c => ones(10))
    df7 = PSI.SequentialWriteDataFrame(
        :a => 5 * ones(10),
        :b => 7 * ones(10),
        :c => 9 * ones(10),
    )

    PSI.set_next_rows!(df6, df7[3, :])
    @test PSI.get_last_recorded_row(df6) == 1

    PSI.set_next_rows!(df6, df7[3:9, :])
    @test PSI.get_last_recorded_row(df6) == 8
end
