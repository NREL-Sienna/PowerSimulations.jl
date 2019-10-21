@testset "DeviceModel Tests" begin
    @test_throws ArgumentError DeviceModel(PSY.ThermalGen, PSI.ThermalStandardUnitCommitment)
    @test_throws ArgumentError DeviceModel(PSY.ThermalStandard, PSI.AbstractDeviceFormulation)
end

@testset "OperationModel Tests" begin
    for p in [true, false]
        t = OperationModel(TestOptModel, CopperPlatePowerModel, c_sys5; parameters = p)
        @test PSI.model_has_parameters(t.canonical) == p
    end
end
