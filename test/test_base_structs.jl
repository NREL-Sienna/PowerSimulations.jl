@testset "DeviceModel Tests" begin
    @test_throws ArgumentError DeviceModel(PSY.ThermalGen, PSI.ThermalUnitCommitment)
    @test_throws ArgumentError DeviceModel(PSY.ThermalStandard, PSI.AbstractDeviceFormulation)
    @test_throws ArgumentError PSI.CanonicalModel(JuMP.Model(),
                                                nothing,
                                                false,
                                                true,
                                                1:24,
                                                Dates.Hour(1),
                                                Dates.now(),
                                                Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                                                Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                                                JuMP.AffExpr(0),
                                                Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                                                nothing,
                                                Dict{Symbol, Array{InitialCondition}}(),
                                                nothing)
end

@testset "OperationModel Tests" begin
    for p in [true, false]
        t = OperationModel(TestOptModel, CopperPlatePowerModel, c_sys5; parameters = p)
        @test PSI.model_has_parameters(t.canonical) == p
    end
end
