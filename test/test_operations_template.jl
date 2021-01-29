# This file is WIP while the interface for templates is finalized
@testset "Manual Operations Template" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel)
    set_component_model!(template, "Loads", DeviceModel(PowerLoad, StaticPowerLoad))
    set_component_model!(
        template,
        "Generators",
        DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    )
    set_component_model!(template, "Line", DeviceModel(Line, StaticLineUnbounded))
    @test !isempty(template.devices)
    @test !isempty(template.branches)
    @test isempty(template.services)
end

@testset "Operations Template Overwrite" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel)
    set_component_model!(template, "Loads", DeviceModel(PowerLoad, StaticPowerLoad))
    set_component_model!(
        template,
        "Generators",
        DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    )
    @test_logs (:info, "Overwriting Generators existing model") set_component_model!(
        template,
        "Generators",
        DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
    )
    @test template.devices["Generators"].formulation == ThermalBasicUnitCommitment
    @test_throws IS.ConflictingInputsError set_component_model!(template, "Loads1", DeviceModel(PowerLoad, StaticPowerLoad))
end

@testset "Provided Templates Tests" begin
    uc_template = template_unit_commitment()
    @test !isempty(uc_template.devices)
    @test uc_template.devices["ThermalGenerators"].formulation == ThermalBasicUnitCommitment
    uc_template = template_unit_commitment(network = DCPPowerModel)
    @test get_transmission_model(uc_template) == DCPPowerModel
    @test !isempty(uc_template.branches)

    ed_template = template_economic_dispatch()
    @test !isempty(ed_template.devices)
    @test isempty(ed_template.branches)
    @test ed_template.devices["ThermalGenerators"].formulation == ThermalDispatch
    ed_template = template_economic_dispatch(network = ACPPowerModel)
    @test get_transmission_model(ed_template) == ACPPowerModel
    @test !isempty(ed_template.branches)
end
