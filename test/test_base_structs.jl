@testset "DeviceModel Tests" begin
    @test_throws ArgumentError DeviceModel(PSY.ThermalGen, PSI.ThermalUnitCommitment)
    @test_throws ArgumentError DeviceModel(PSY.ThermalStandard, PSI.AbstractDeviceFormulation)
end
