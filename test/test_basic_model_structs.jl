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
            component_type=RenewableDispatch,
            source=ActivePowerVariable,
            affected_values=[ActivePowerVariable],
        ),
        LowerBoundFeedforward(
            component_type=RenewableDispatch,
            source=ActivePowerVariable,
            affected_values=[ActivePowerVariable],
        ),
        SemiContinuousFeedforward(
            component_type=ThermalMultiStart,
            source=OnVariable,
            affected_values=[ActivePowerVariable, ReactivePowerVariable],
        ),
        EnergyLimitFeedforward(
            component_type=GenericBattery,
            source=EnergyVariable,
            affected_values=[EnergyVariable],
            number_of_periods=10,
        ),
    ]

    for ff in ffs
        for av in PSI.get_affected_values(ff)
            @test isa(av, PSI.VariableKey)
        end
    end

    ff = FixValueFeedforward(
        component_type=HydroDispatch,
        source=OnVariable,
        affected_values=[OnStatusParameter],
    )

    for av in PSI.get_affected_values(ff)
        @test isa(av, PSI.ParameterKey)
    end

    @test_throws ErrorException EnergyLimitFeedforward(
        component_type=GenericBattery,
        source=EnergyVariable,
        affected_values=[OnStatusParameter],
        number_of_periods=10,
    )

    @test_throws ErrorException UpperBoundFeedforward(
        component_type=RenewableDispatch,
        source=ActivePowerVariable,
        affected_values=[OnStatusParameter],
    )

    @test_throws ErrorException LowerBoundFeedforward(
        component_type=RenewableDispatch,
        source=ActivePowerVariable,
        affected_values=[OnStatusParameter],
    )

    @test_throws ErrorException SemiContinuousFeedforward(
        component_type=ThermalMultiStart,
        source=OnVariable,
        affected_values=[ActivePowerVariable, OnStatusParameter],
    )
end
