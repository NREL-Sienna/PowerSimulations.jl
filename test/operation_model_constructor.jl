#Inputs to the OperationModel

@testset "Operation Model Constructor with Params" begin
    #These tests with Unit Commitment must not add Parameters to the Canonical Model. 
    # Once a formulation with Parameters is available the tests need to be updated
    #=
    devices = Dict{Symbol, PSI.DeviceModel}(:Generators => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalUnitCommitment),
                                            :Loads => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, PSI.DeviceModel}(:Lines => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))
    services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))
    PTDF, A = PowerSystems.buildptdf(branches5, nodes5)

    op_model = PSI.PowerOperationModel(TestOptModel, PM.StandardACPForm, devices, branches, services, sys5b)
    @test :var_active in keys(op_model.canonical_model.expressions) && :var_reactive in keys(op_model.canonical_model.expressions)
    @test (:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PM.DCPlosslessForm, devices, branches, services, sys5b)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test (:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.StandardPTDFForm, devices, branches, services, sys5b; PTDF = PTDF)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test (:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.CopperPlatePowerModel, devices, branches, services, sys5b)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test (:params in keys(op_model.canonical_model.JuMPmodel.ext))
    =#

    devices = Dict{Symbol, PSI.DeviceModel}(:Generators => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalDispatch),
    :Loads => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, PSI.DeviceModel}(:Lines => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))
    services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))
    PTDF, A = PowerSystems.buildptdf(branches5, nodes5)

    op_model = PSI.PowerOperationModel(TestOptModel, PM.StandardACPForm, devices, branches, services, sys5b)
    @test :var_active in keys(op_model.canonical_model.expressions) && :var_reactive in keys(op_model.canonical_model.expressions)
    @test (:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PM.DCPlosslessForm, devices, branches, services, sys5b)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test (:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.StandardPTDFForm, devices, branches, services, sys5b; PTDF = PTDF)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test (:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.CopperPlatePowerModel, devices, branches, services, sys5b)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test (:params in keys(op_model.canonical_model.JuMPmodel.ext))
end

@testset "Operation Model Constructor without Params" begin
    devices = Dict{Symbol, PSI.DeviceModel}(:Generators => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalUnitCommitment),
    :Loads => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, PSI.DeviceModel}(:Lines => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))
    services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))
    PTDF, A = PowerSystems.buildptdf(branches5, nodes5)

    op_model = PSI.PowerOperationModel(TestOptModel, PM.StandardACPForm, devices, branches, services, sys5b; parameters = false)
    @test :var_active in keys(op_model.canonical_model.expressions) && :var_reactive in keys(op_model.canonical_model.expressions)
    @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PM.DCPlosslessForm, devices, branches, services, sys5b; parameters = false)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.StandardPTDFForm, devices, branches, services, sys5b; PTDF = PTDF, parameters = false)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.CopperPlatePowerModel, devices, branches, services, sys5b; parameters = false)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))    

    devices = Dict{Symbol, PSI.DeviceModel}(:Generators => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalDispatch),
                                            :Loads => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, PSI.DeviceModel}(:Lines => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))
    services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))
    PTDF, A = PowerSystems.buildptdf(branches5, nodes5)

    op_model = PSI.PowerOperationModel(TestOptModel, PM.StandardACPForm, devices, branches, services, sys5b; parameters = false)
    @test :var_active in keys(op_model.canonical_model.expressions) && :var_reactive in keys(op_model.canonical_model.expressions)
    @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PM.DCPlosslessForm, devices, branches, services, sys5b; parameters = false)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.StandardPTDFForm, devices, branches, services, sys5b; PTDF = PTDF, parameters = false)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))

    op_model = PSI.PowerOperationModel(TestOptModel, PSI.CopperPlatePowerModel, devices, branches, services, sys5b; parameters = false)
    @test :var_active in keys(op_model.canonical_model.expressions)
    @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))

end


@testset "Build Operation Models" begin
    SCED = PSI.SCEconomicDispatch(sys5b; optimizer = GLPK_optimizer);
    OPF = PSI.OptimalPowerFlow(sys5b, PM.StandardACPForm, optimizer = ipopt_optimizer)
    UC = PSI.UnitCommitment(sys5b, PM.DCPlosslessForm; optimizer = GLPK_optimizer)
end
