#Some of these tests require building the full system to have a valid PM object
@testset "AC Power Flow Monitored Line Flow Constraints and bounds" begin
    system = build_c_sys5_ml()
    line = PSY.get_component(Line, system, "1")
    PSY.convert_component!(MonitoredLine, line, system)
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}(
        :ML => DeviceModel(MonitoredLine, StaticLineBounds),
        :L => DeviceModel(Line, StaticLineBounds),
    )
    template = OperationsProblemTemplate(StandardPTDFModel, devices, branches, services)
    limits = PSY.get_flowlimits(PSY.get_component(MonitoredLine, system, "1"))
    op_problem_m = OperationsProblem(
        PSI.GenericOpProblem,
        template,
        system;
        optimizer = OSQP_optimizer,
        PTDF = build_PTDF5(),
    )
    for b in PSI.get_variable(op_problem_m.psi_container, :Fp__Line)
        @test JuMP.has_lower_bound(b)
        @test JuMP.has_upper_bound(b)
    end
    for b in PSI.get_variable(op_problem_m.psi_container, :Fp__MonitoredLine)
        @test JuMP.has_lower_bound(b)
        @test JuMP.has_upper_bound(b)
    end
    monitored = solve!(op_problem_m)
    flow = monitored.variable_values[:Fp__MonitoredLine][1, 1]
    @test isapprox(flow, limits.from_to, atol = 1e-3)
end

@testset "AC Power Flow Monitored Line Flow Constraints" begin
    system = build_c_sys5_ml()
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    branches = Dict{Symbol, DeviceModel}(
        :ML => DeviceModel(MonitoredLine, FlowMonitoredLine),
        :L => DeviceModel(Line, StaticLineBounds),
    )
    template = OperationsProblemTemplate(ACPPowerModel, devices, branches, services)
    line = PSY.get_component(Line, system, "1")
    PSY.convert_component!(MonitoredLine, line, system)
    line = PSY.get_component(MonitoredLine, system, "1")
    limits = PSY.get_flowlimits(line)
    op_problem_m =
        OperationsProblem(TestOpProblem, template, system; optimizer = ipopt_optimizer)
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
        :ML => DeviceModel(MonitoredLine, FlowMonitoredLine),
        :L => DeviceModel(Line, StaticLineBounds),
    )
    template = OperationsProblemTemplate(DCPPowerModel, devices, branches, services)
    system = build_c_sys5_ml()
    line = PSY.get_component(Line, system, "1")
    PSY.convert_component!(MonitoredLine, line, system)
    line = PSY.get_component(MonitoredLine, system, "1")
    limits = PSY.get_flowlimits(PSY.get_component(MonitoredLine, system, "1"))
    rate = PSY.get_rate(PSY.get_component(MonitoredLine, system, "1"))
    op_problem_m =
        OperationsProblem(TestOpProblem, template, system; optimizer = ipopt_optimizer)
    monitored = solve!(op_problem_m)
    fp = monitored.variable_values[:Fp__MonitoredLine][1, 1]
    @test isapprox(fp, limits.from_to, atol = 1e-3)
    @test isapprox(fp, rate, atol = 1e-3)
end
