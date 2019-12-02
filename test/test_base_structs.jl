@testset "DeviceModel Tests" begin
    @test_throws ArgumentError DeviceModel(ThermalGen, ThermalStandardUnitCommitment)
    @test_throws ArgumentError DeviceModel(ThermalStandard, PSI.AbstractDeviceFormulation)
end

@testset "OperationsProblem Tests" begin
    for p in [true, false]
        t = OperationsProblem(TestOpProblem, CopperPlatePowerModel, c_sys5; use_parameters = p)
        @test PSI.model_has_parameters(t.psi_container) == p
    end
end
