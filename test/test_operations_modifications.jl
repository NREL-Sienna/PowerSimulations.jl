devices = Dict{Symbol, DeviceModel}(
    :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
)
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(Line, StaticLineUnbounded))
services = Dict{Symbol, ServiceModel}()

@testset "Operation set ref models" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    op_problem = OperationsProblem(TestOpProblem, template, c_sys5)
    set_transmission_model!(op_problem, DCPLLPowerModel)
    @test op_problem.template.transmission == DCPLLPowerModel

    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    op_problem = OperationsProblem(TestOpProblem, template, c_sys5)
    new_devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    set_devices_template!(op_problem, new_devices)
    @test op_problem.template.devices[:Generators].formulation == ThermalBasicUnitCommitment
    jump_model = op_problem.psi_container.JuMPmodel
    @test ((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(jump_model)) ==
          true

    template = OperationsProblemTemplate(DCPPowerModel, devices, branches, services)
    op_problem = OperationsProblem(TestOpProblem, template, c_sys5)
    new_branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(Line, StaticLine))
    set_branches_template!(op_problem, new_branches)
    @test op_problem.template.branches[:L].formulation == StaticLine
end

@testset "Operation set models" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    op_problem = OperationsProblem(TestOpProblem, template, c_sys5)
    set_device_model!(
        op_problem,
        :Generators,
        DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
    )
    @test op_problem.template.devices[:Generators].formulation == ThermalBasicUnitCommitment
    jump_model = op_problem.psi_container.JuMPmodel
    @test ((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(jump_model)) ==
          true

    template = OperationsProblemTemplate(DCPPowerModel, devices, branches, services)
    op_problem = OperationsProblem(TestOpProblem, template, c_sys5)
    set_branch_model!(op_problem, :L, DeviceModel(Line, StaticLine))
    @test op_problem.template.branches[:L].formulation == StaticLine
    services_filled = Dict{Symbol, ServiceModel}(
        :Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
    )
    template_s =
        OperationsProblemTemplate(DCPPowerModel, devices, branches, services_filled)
    op_problem_s = OperationsProblem(TestOpProblem, template_s, c_sys5)
    PSI.set_services_model!(
        op_problem_s,
        :Reserve,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
    )
    @test op_problem_s.template.services[:Reserve].formulation == RangeReserve
    @test_throws IS.ConflictingInputsError set_branch_model!(
        op_problem,
        :Reserve,
        DeviceModel(Line, StaticLine),
    )
    #@test_throws IS.ConflictingInputsError set_services_model!(op_problem_s, collect(keys(branches))[1], ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
end
