@testset "DeviceModel Tests" begin
    @test_throws ArgumentError DeviceModel(ThermalGen, ThermalStandardUnitCommitment)
    @test_throws ArgumentError DeviceModel(ThermalStandard, PSI.AbstractDeviceFormulation)
    @test_throws ArgumentError ServiceModel(AGC, PSI.AbstractServiceFormulation)
    @test_throws ArgumentError ServiceModel(
        VariableReserve{PSY.ReserveUp},
        PSI.AbstractServiceFormulation,
    )
end
