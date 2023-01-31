function get_thermal_standard_uc_template()
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    return template
end

function get_thermal_dispatch_template_network(network=CopperPlatePowerModel)
    template = ProblemTemplate(network)
    set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, MonitoredLine, StaticBranchBounds)
    set_device_model!(template, Line, StaticBranch)
    set_device_model!(template, Transformer2W, StaticBranch)
    set_device_model!(template, TapTransformer, StaticBranch)
    set_device_model!(template, HVDCLine, HVDCP2PLossless)
    return template
end

function get_template_basic_uc_simulation()
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, InterruptiblePowerLoad, StaticPowerLoad)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchRunOfRiver)
    return template
end

function get_template_standard_uc_simulation()
    template = get_template_basic_uc_simulation()
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    return template
end

function get_template_nomin_ed_simulation(network=CopperPlatePowerModel)
    template = ProblemTemplate(network)
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, InterruptiblePowerLoad, PowerLoadDispatch)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchRunOfRiver)
    return template
end

function get_template_hydro_st_uc(network=CopperPlatePowerModel)
    template = ProblemTemplate(network)
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment),
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch),
    set_device_model!(template, PowerLoad, StaticPowerLoad),
    set_device_model!(template, InterruptiblePowerLoad, PowerLoadDispatch),
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirStorage),
    return template
end

function get_template_hydro_st_ed(network=CopperPlatePowerModel, duals=[])
    template = ProblemTemplate(network)
    set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, InterruptiblePowerLoad, PowerLoadDispatch)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirStorage)
    return template
end

function get_template_dispatch_with_network(network=StandardPTDFModel)
    template = ProblemTemplate(network)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template, Line, StaticBranch)
    set_device_model!(template, Transformer2W, StaticBranch)
    set_device_model!(template, TapTransformer, StaticBranch)
    set_device_model!(template, HVDCLine, HVDCP2PLossless)
    return template
end
