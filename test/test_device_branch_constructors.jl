#Some of these tests require building the full system to have a valid PM object
@testset "AC Power Flow Monitored Line Flow Constraints" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}(
        :L => DeviceModel(PSY.MonitoredLine, PSI.FlowMonitoredLine),
    )
    template = OperationsProblemTemplate(ACPPowerModel, devices, branches, services)
    system = c_sys5_ml
    line = PSY.get_component(Line, system, "1")
    PSY.convert_component!(MonitoredLine, line, system)
    limits = PSY.get_flowlimits(PSY.get_component(MonitoredLine, system, "1"))
    op_problem_m = OperationsProblem(
        TestOpProblem,
        template,
        system;
        optimizer = ipopt_optimizer,
        use_parameters = false,
    )
    monitored = solve!(op_problem_m)
    fq = monitored.variable_values[:FqFT__MonitoredLine][1, 1]
    fp = monitored.variable_values[:FpFT__MonitoredLine][1, 1]
    flow = sqrt((fp[1])^2 + (fq[1])^2)
    @test isapprox(flow, limits.from_to, atol = 1e-3)
end

@testset "DC PowerFlow Monitored Line Branch Flow constraints" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}(
        :L => DeviceModel(PSY.MonitoredLine, PSI.FlowMonitoredLine),
    )
    template = OperationsProblemTemplate(DCPPowerModel, devices, branches, services)
    system = c_sys5_ml
    limits = PSY.get_flowlimits(PSY.get_component(MonitoredLine, system, "1"))
    rate = PSY.get_rate(PSY.get_component(MonitoredLine, system, "1"))
    op_problem_m = OperationsProblem(
        TestOpProblem,
        template,
        system;
        optimizer = ipopt_optimizer,
        use_parameters = false,
    )
    monitored = solve!(op_problem_m)
    fp = monitored.variable_values[:Fp__MonitoredLine][1, 1]
    @test isapprox(fp, limits.from_to, atol = 1e-3)
    @test isapprox(fp, rate, atol = 1e-3)
end
