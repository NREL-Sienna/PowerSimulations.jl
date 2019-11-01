devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, ThermalDispatch),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, StaticPowerLoad))
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, StaticLineUnbounded))
services = Dict{Symbol, ServiceModel}()

@testset "Operation set ref models" begin
    template = FormulationTemplate(CopperPlatePowerModel, devices, branches, services);
    op_problem = OperationsProblem(TestOptModel, template, c_sys5)
    set_transmission_ref!(op_problem, DCPLLPowerModel)
    @test op_problem.template.transmission == DCPLLPowerModel

    template = FormulationTemplate(CopperPlatePowerModel, devices, branches, services);
    op_problem = OperationsProblem(TestOptModel, template, c_sys5)
    new_devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment),
                                            :Loads =>  DeviceModel(PSY.PowerLoad, StaticPowerLoad))
    set_devices_ref!(op_problem, new_devices)
    @test op_problem.template.devices[:Generators].formulation == ThermalBasicUnitCommitment
    jump_model = op_problem.canonical.JuMPmodel
    @test ((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(jump_model)) == true

    template = FormulationTemplate(DCPPowerModel, devices, branches, services);
    op_problem = OperationsProblem(TestOptModel, template, c_sys5)
    new_branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, StaticLine))
    set_branches_ref!(op_problem, new_branches)
    @test op_problem.template.branches[:L].formulation == StaticLine
end


@testset "Operation set models" begin
    template = FormulationTemplate(CopperPlatePowerModel, devices, branches, services);
    op_problem = OperationsProblem(TestOptModel, template, c_sys5)
    set_device_model!(op_problem, :Generators, DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment))
    @test op_problem.template.devices[:Generators].formulation == ThermalBasicUnitCommitment
    jump_model = op_problem.canonical.JuMPmodel
    @test ((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(jump_model)) == true

    template = FormulationTemplate(DCPPowerModel, devices, branches, services);
    op_problem = OperationsProblem(TestOptModel, template, c_sys5)
    set_branch_model!(op_problem, :L, DeviceModel(PSY.Line, StaticLine))
    @test op_problem.template.branches[:L].formulation == StaticLine
end
