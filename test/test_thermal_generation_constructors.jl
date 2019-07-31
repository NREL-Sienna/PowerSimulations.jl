@testset "ThermalGen data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't devices of type ThermalStandard, consider changing the device models"
    model = DeviceModel(ThermalStandard, PSI.ThermalUnitCommitment)
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5_re_only)
    @test_logs (:warn, warn_message) construct_device!(op_model, :Thermal, model)
end

################################### Unit Commitment tests ##################################
@testset "Thermal UC With DC - PF" begin
    bin_variable_names = [:ON_ThermalStandard,
                          :START_ThermalStandard,
                          :STOP_ThermalStandard]
    uc_constraint_names = [:ramp_up_ThermalStandard,
                           :ramp_dn_ThermalStandard,
                           :duration_up_ThermalStandard,
                           :duration_dn_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalUnitCommitment)

    @info "5-Bus testing"
    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5_uc)
    construct_device!(op_model, :Thermal, model)
    moi_tests(op_model, false, 480, 0, 480, 120, 120, true)
    psi_constraint_test(op_model, uc_constraint_names)
    psi_checkbinvar_test(op_model, bin_variable_names)
    psi_checkobjfun_test(op_model, GAEVF)

    op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5_uc; parameters = true)
    construct_device!(op_model, :Thermal, model)
    moi_tests(op_model, true, 480, 0, 468, 132, 120, true)
    psi_constraint_test(op_model, uc_constraint_names)
    psi_checkbinvar_test(op_model, bin_variable_names)
    psi_checkobjfun_test(op_model, GAEVF)

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 480, 0, 240, 120, 120, true)
        psi_checkbinvar_test(op_model, bin_variable_names)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end

@testset "Thermal UC With AC - PF" begin
    bin_variable_names = [:ON_ThermalStandard,
                          :START_ThermalStandard,
                          :STOP_ThermalStandard]
    uc_constraint_names = [:ramp_up_ThermalStandard,
                           :ramp_dn_ThermalStandard,
                           :duration_up_ThermalStandard,
                           :duration_dn_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalUnitCommitment)

    @info "5-Bus testing"
    op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys5_uc)
    construct_device!(op_model, :Thermal, model)
    moi_tests(op_model, false, 600, 0, 600, 240, 120, true)
    psi_constraint_test(op_model, uc_constraint_names)
    psi_checkbinvar_test(op_model, bin_variable_names)
    psi_checkobjfun_test(op_model, GAEVF)

    op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys5_uc; parameters = true)
    construct_device!(op_model, :Thermal, model)
    moi_tests(op_model, true, 600, 0, 588, 252, 120, true)
    psi_constraint_test(op_model, uc_constraint_names)
    psi_checkbinvar_test(op_model, bin_variable_names)
    psi_checkobjfun_test(op_model, GAEVF)

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 600, 0, 360, 240, 120, true)
        psi_checkbinvar_test(op_model, bin_variable_names)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


################################### Basic Dispatch tests ###################################
@testset "Thermal Dispatch With DC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 120, 0, 0, 0, false)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 120, 0, 0, 0, false)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


@testset "Thermal Dispatch With AC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 240, 0, 0, 0, false)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 240, 0, 0, 0, false)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


################################### No Minimum Dispatch tests ##############################

@testset "Thermal Dispatch NoMin With DC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatchNoMin)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 120, 0, 0, 0, false)
        moi_ubvalue_test(op_model, :activerange_ThermalStandard, 0.0)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 120, 0, 0, 0, false)
        moi_ubvalue_test(op_model, :activerange_ThermalStandard, 0.0)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


@testset "Thermal Dispatch NoMin With AC - PF" begin
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatchNoMin)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys5; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 240, 0, 0, 0, false)
        moi_ubvalue_test(op_model, :activerange_ThermalStandard, 0.0)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 240, 0, 0, 0, false)
        moi_ubvalue_test(op_model, :activerange_ThermalStandard, 0.0)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


################################### Ramp Limited Testing ##################################
@testset "Thermal Ramp Limited Dispatch With DC - PF" begin
    constraint_names = [:ramp_up_ThermalStandard, :ramp_dn_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys5_uc; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 120, 96, 0, 0, false)
        psi_constraint_test(op_model, constraint_names)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.DCPlosslessForm, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 120, 120, 0, 0, 0, false)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end


@testset "Thermal Ramp Limited Dispatch With AC - PF" begin
    constraint_names = [:ramp_up_ThermalStandard, :ramp_dn_ThermalStandard]
    model = DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited)
    @info "5-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys5_uc; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 240, 96, 0, 0, false)
        psi_constraint_test(op_model, constraint_names)
        psi_checkobjfun_test(op_model, GAEVF)
    end

    @info "14-Bus testing"
    for p in [true, false]
        op_model = OperationModel(TestOptModel, PM.StandardACPForm, c_sys14; parameters = p)
        construct_device!(op_model, :Thermal, model)
        moi_tests(op_model, p, 240, 240, 0, 0, 0, false)
        psi_checkobjfun_test(op_model, GQEVF)
    end
end
