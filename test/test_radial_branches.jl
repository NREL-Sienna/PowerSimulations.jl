function _updated_5bus_sys_with_extensions()
    sys = PSB.build_system(PSITestSystems, "c_sys5_uc")
    new_sys = deepcopy(sys)
    ################################
    #### Create Extension Buses ####
    ################################

    busC = get_component(ACBus, new_sys, "nodeC")

    busC_ext1 = ACBus(;
        number = 301,
        name = "nodeC_ext1",
        bustype = ACBusTypes.PQ,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.9, max = 1.05),
        base_voltage = 230.0,
        area = nothing,
        load_zone = nothing,
    )

    busC_ext2 = ACBus(;
        number = 302,
        name = "nodeC_ext2",
        bustype = ACBusTypes.PQ,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.9, max = 1.05),
        base_voltage = 230.0,
        area = nothing,
        load_zone = nothing,
    )

    add_components!(new_sys, [busC_ext1, busC_ext2])

    ################################
    #### Create Extension Lines ####
    ################################

    line_C_to_ext1 = Line(;
        name = "C_to_ext1",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = Arc(; from = busC, to = busC_ext1),
        #r = 0.00281,
        r = 0.0,
        x = 0.0281,
        b = (from = 0.00356, to = 0.00356),
        rate = 2.0,
        angle_limits = (min = -0.7, max = 0.7),
    )

    line_ext1_to_ext2 = Line(;
        name = "ext1_to_ext2",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = Arc(; from = busC_ext1, to = busC_ext2),
        #r = 0.00281,
        r = 0.0,
        x = 0.0281,
        b = (from = 0.00356, to = 0.00356),
        rate = 2.0,
        angle_limits = (min = -0.7, max = 0.7),
    )

    add_components!(new_sys, [line_C_to_ext1, line_ext1_to_ext2])

    ###################################
    ###### Update Extension Loads #####
    ###################################

    load_bus3 = get_component(PowerLoad, new_sys, "Bus3")

    load_ext1 = PowerLoad(;
        name = "Bus_ext1",
        available = true,
        bus = busC_ext1,
        active_power = 1.0,
        reactive_power = 0.9861 / 3,
        base_power = 100.0,
        max_active_power = 1.0,
        max_reactive_power = 0.9861 / 3,
    )

    load_ext2 = PowerLoad(;
        name = "Bus_ext2",
        available = true,
        bus = busC_ext2,
        active_power = 1.0,
        reactive_power = 0.9861 / 3,
        base_power = 100.0,
        max_active_power = 1.0,
        max_reactive_power = 0.9861 / 3,
    )

    add_components!(new_sys, [load_ext1, load_ext2])

    copy_time_series!(load_ext1, load_bus3)
    copy_time_series!(load_ext2, load_bus3)

    set_active_power!(load_bus3, 1.0)
    set_max_active_power!(load_bus3, 1.0)
    set_reactive_power!(load_bus3, 0.3287)
    set_max_reactive_power!(load_bus3, 0.3287)
    return new_sys
end

@testset "StandardPTDF Radial Branches Test" begin
    new_sys = _updated_5bus_sys_with_extensions()

    net_model = StandardPTDFModel

    template_uc = template_unit_commitment(;
        network = NetworkModel(net_model;
            reduce_radial_branches = true,
            use_slacks = false,
        ),
    )
    thermal_model = ThermalStandardUnitCommitment
    set_device_model!(template_uc, ThermalStandard, thermal_model)

    ##### Solve Reduced Model ####
    solver = GLPK_optimizer
    uc_model_red = DecisionModel(
        template_uc,
        new_sys;
        optimizer = solver,
        name = "UC_RED",
        store_variable_names = true,
    )

    @test build!(uc_model_red; output_dir = mktempdir(; cleanup = true)) ==
          PSI.BuildStatus.BUILT
    solve!(uc_model_red)

    res_red = ProblemResults(uc_model_red)

    flow_lines = read_variable(res_red, "FlowActivePowerVariable__Line")
    line_names = DataFrames.names(flow_lines)[2:end]

    ##### Solve Original Model ####
    template_uc_orig = template_unit_commitment(;
        network = NetworkModel(net_model;
            reduce_radial_branches = false,
            use_slacks = false,
        ),
    )
    set_device_model!(template_uc_orig, ThermalStandard, thermal_model)

    uc_model_orig = DecisionModel(
        template_uc_orig,
        new_sys;
        optimizer = solver,
        name = "UC_ORIG",
        store_variable_names = true,
    )

    @test build!(uc_model_orig; output_dir = mktempdir(; cleanup = true)) ==
          PSI.BuildStatus.BUILT
    solve!(uc_model_orig)

    res_orig = ProblemResults(uc_model_orig)

    flow_lines_orig = read_variable(res_orig, "FlowActivePowerVariable__Line")

    for line in line_names
        @test isapprox(flow_lines[!, line], flow_lines_orig[!, line])
    end
end

@testset "DCPPowerModel Radial Branches Test" begin
    new_sys = _updated_5bus_sys_with_extensions()

    net_model = DCPPowerModel

    template_uc = template_unit_commitment(;
        network = NetworkModel(net_model;
            reduce_radial_branches = true,
            use_slacks = false,
        ),
    )
    thermal_model = ThermalStandardUnitCommitment
    set_device_model!(template_uc, ThermalStandard, thermal_model)

    ##### Solve Reduced Model ####
    solver = GLPK_optimizer
    uc_model_red = DecisionModel(
        template_uc,
        new_sys;
        optimizer = solver,
        name = "UC_RED",
        store_variable_names = true,
    )

    @test build!(uc_model_red; output_dir = mktempdir(; cleanup = true)) ==
          PSI.BuildStatus.BUILT
    solve!(uc_model_red)

    res_red = ProblemResults(uc_model_red)

    flow_lines = read_variable(res_red, "FlowActivePowerVariable__Line")
    line_names = DataFrames.names(flow_lines)[2:end]

    ##### Solve Original Model ####
    template_uc_orig = template_unit_commitment(;
        network = NetworkModel(net_model;
            reduce_radial_branches = false,
            use_slacks = false,
        ),
    )
    set_device_model!(template_uc_orig, ThermalStandard, thermal_model)

    uc_model_orig = DecisionModel(
        template_uc_orig,
        new_sys;
        optimizer = solver,
        name = "UC_ORIG",
        store_variable_names = true,
    )

    @test build!(uc_model_orig; output_dir = mktempdir(; cleanup = true)) ==
          PSI.BuildStatus.BUILT
    solve!(uc_model_orig)

    res_orig = ProblemResults(uc_model_orig)

    flow_lines_orig = read_variable(res_orig, "FlowActivePowerVariable__Line")

    for line in line_names
        @test isapprox(flow_lines[!, line], flow_lines_orig[!, line])
    end
end
