@testset "DeviceModel Tests" begin
    @test_throws ArgumentError DeviceModel(PSY.ThermalGen, PSI.ThermalUnitCommitment)
    @test_throws ArgumentError DeviceModel(PSY.ThermalStandard, PSI.AbstractDeviceFormulation)
    @test_throws ArgumentError PSI.CanonicalModel(JuMP.Model(),
                                                false,
                                                true,
                                                1:24,
                                                Dates.Hour(1),
                                                Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                                                Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                                                JuMP.AffExpr(0),
                                                Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                                                nothing,
                                                Dict{Symbol, Array{InitialCondition}}(),
                                                nothing)
end
