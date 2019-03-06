#Inputs to the OperationModel

@testset "Operation Model Constructor" begin
    devices = Dict{String, PSI.DeviceModel}("Generators" => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalUnitCommitment),
                    "Loads" => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{String, PSI.DeviceModel}("Lines" => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))
    services = Dict{String, PSI.ServiceModel}("Reserves" => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))
    PTDF, A = PowerSystems.buildptdf(branches5, nodes5)

    op_model = PSI.PowerOperationModel(TestOptModel, PM.StandardACPForm, devices, branches, services, sys5b)
    @test "var_active" in keys(op_model.canonical_model.expressions) && "var_reactive" in keys(op_model.canonical_model.expressions)

    op_model = PSI.PowerOperationModel(TestOptModel, PM.DCPlosslessForm, devices, branches, services, sys5b)
    @test "var_active" in keys(op_model.canonical_model.expressions)

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.StandardPTDFModel, devices, branches, services, sys5b; PTDF = PTDF)
    @test "var_active" in keys(op_model.canonical_model.expressions)

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.CopperPlatePowerModel, devices, branches, services, sys5b)
    @test "var_active" in keys(op_model.canonical_model.expressions)
end