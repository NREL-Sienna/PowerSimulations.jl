###############################
###### Model Templates ########
###############################

# Some models are commented for RTS model

function set_uc_models!(template_uc)
    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, RenewableFix, FixedOutput)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, TapTransformer, StaticBranchUnbounded)
    set_device_model!(template_uc, HydroEnergyReservoir, HydroDispatchRunOfRiver)
    set_service_model!(
        template_uc,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve; use_slacks = true),
    )
    set_service_model!(
        template_uc,
        ServiceModel(VariableReserve{ReserveDown}, RangeReserve; use_slacks = true),
    )
    return
end

###############################
###### Get Templates ##########
###############################

### PTDF Bounded ####

function get_uc_ptdf_template(sys)
    template_uc = ProblemTemplate(
        NetworkModel(
            StandardPTDFModel;
            use_slacks = false,
            PTDF_matrix = PTDF(sys),
            duals = [CopperPlateBalanceConstraint],
        ),
    )
    set_uc_models!(template_uc)
    set_device_model!(template_uc, Line, StaticBranch)
    return template_uc
end

function get_ed_ptdf_template(sys)
    template_ed = ProblemTemplate(
        NetworkModel(
            StandardPTDFModel;
            use_slacks = true,
            PTDF_matrix = PTDF(sys),
            duals = [CopperPlateBalanceConstraint],
        ),
    )
    set_uc_models!(template_ed)
    set_device_model!(template_ed, ThermalStandard, ThermalStandardDispatch)
    return template_ed
end

#### PTDF Unbounded ####

function get_uc_ptdf_unbounded_template(sys)
    template_uc = get_uc_ptdf_template(sys)
    set_device_model!(template_uc, Line, StaticBranchUnbounded)
    return template_uc
end

function get_ed_ptdf_unbounded_template(sys_rts_rt)
    template_ed = get_ed_ptdf_template(sys_rts_rt)
    set_device_model!(template_uc, Line, StaticBranchUnbounded)
    return template_ed
end

####### Simulations #####
