c_sys5_uc_re = PSB.build_system(
    PSITestSystems,
    "c_sys5_uc_re";
    add_single_time_series = true,
    force_build = true,
)

template_dm = get_thermal_standard_uc_template()
set_service_model!(
    template_dm,
    ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "test"),
)
UC = DecisionModel(template_dm, c_sys5_uc_re; name = "UC", optimizer = GLPK_optimizer)

template_em =  get_thermal_dispatch_template_network()
set_device_model!(template_em, RenewableDispatch, RenewableFullDispatch)
ED = EmulationModel(template_em, c_sys5_uc_re; name = "ED", optimizer = GLPK_optimizer)
