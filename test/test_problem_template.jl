# This file is WIP while the interface for templates is finalized
@testset "Manual Operations Template" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template, Line, StaticBranchUnbounded)
    @test !isempty(template.devices)
    @test !isempty(template.branches)
    @test isempty(template.services)
end

@testset "Operations Template Overwrite" begin
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    @test_logs (:warn, "Overwriting ThermalStandard existing model") set_device_model!(
        template,
        DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
    )
    @test PSI.get_formulation(template.devices[:ThermalStandard]) ==
          ThermalBasicUnitCommitment
end

@testset "Provided Templates Tests" begin
    uc_template = template_unit_commitment()
    @test !isempty(uc_template.devices)
    @test PSI.get_formulation(uc_template.devices[:ThermalStandard]) ==
          ThermalBasicUnitCommitment
    uc_template = template_unit_commitment(; network = DCPPowerModel)
    @test get_network_formulation(uc_template) == DCPPowerModel
    @test !isempty(uc_template.branches)
    @test !isempty(uc_template.services)

    ed_template = template_economic_dispatch()
    @test !isempty(ed_template.devices)
    @test PSI.get_formulation(ed_template.devices[:ThermalStandard]) == ThermalBasicDispatch
    ed_template = template_economic_dispatch(; network = ACPPowerModel)
    @test get_network_formulation(ed_template) == ACPPowerModel
    @test !isempty(ed_template.branches)
    @test !isempty(ed_template.services)
end
