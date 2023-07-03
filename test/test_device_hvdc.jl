@testset "HVDC System Tests" begin
    sys_5 = build_system(PSISystems, "sys10_pjm_ac_dc")
    template_uc = ProblemTemplate(NetworkModel(
        DCPPowerModel,
        #use_slacks=true,
        #PTDF_matrix=PTDF(sys_5),
        #duals=[CopperPlateBalanceConstraint],
    ))

    #set_device_model!(template_uc, ThermalMultiStart, ThermalCompactUnitCommitment)
    set_device_model!(template_uc, ThermalStandard, ThermalCompactUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranch))
    set_device_model!(template_uc, DeviceModel(InterconnectingConverter, LossLessConverter))
    set_device_model!(template_uc, DeviceModel(TModelHVDCLine, LossLessLine))

    model = DecisionModel(
        template_uc,
        sys_5;
        name="UC",
        optimizer=HiGHS_optimizer,
        direct_mode_optimizer=true,
    )
    @test build!(model; output_dir=mktempdir()) == PSI.BuildStatus.BUILT
end