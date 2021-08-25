@testset "DeviceModel Tests" begin
    @test_throws ArgumentError DeviceModel(ThermalGen, ThermalStandardUnitCommitment)
    @test_throws ArgumentError DeviceModel(ThermalStandard, PSI.AbstractDeviceFormulation)
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

@testset "FeedForward Struct Tests" begin
    ff = UpperBoundFF(
        device_type = RenewableDispatch,
        variable_source_problem = ActivePowerVariable,
        affected_variables = [ActivePowerVariable],
    )

    @test isa(PSI.get_variable_source_problem_key(ff), PSI.VariableKey)

    ff = SemiContinuousFF(
        device_type = ThermalMultiStart,
        binary_source_problem = OnVariable,
        affected_variables = [ActivePowerVariable, ReactivePowerVariable],
    )

    @test isa(PSI.get_binary_source_problem_key(ff), PSI.VariableKey)

    ff = IntegralLimitFF(
        device_type = GenericBattery,
        variable_source_problem = EnergyVariable,
        affected_variables = [EnergyVariable],
    )

    @test isa(PSI.get_variable_source_problem_key(ff), PSI.VariableKey)

    ff = ParameterFF(
        device_type = HydroDispatch,
        variable_source_problem = ActivePowerVariable,
        affected_parameters = [],
    )
end
