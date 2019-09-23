devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.StaticLine),
                                     :T => DeviceModel(PSY.Transformer2W, PSI.StaticTransformer),
                                     :TT => DeviceModel(PSY.TapTransformer , PSI.StaticTransformer))
services = Dict{Symbol, PSI.ServiceModel}()
@testset "Operation Model kwargs with CopperPlatePowerModel base" begin
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    op_model = OperationModel(TestOptModel, model_ref,
                                            c_sys5;
                                            optimizer = GLPK_optimizer,
                                            parameters = true)
    j_model = op_model.canonical.JuMPmodel
    @test (:params in keys(j_model.ext))
    @test JuMP.num_variables(j_model) == 120
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 24
    @test !((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(j_model))
    @test JuMP.objective_function_type(j_model) == JuMP.GenericAffExpr{Float64, VariableRef}

    op_model = OperationModel(TestOptModel, model_ref,
                                            c_sys14;
                                            optimizer = OSQP_optimizer)
    j_model = op_model.canonical.JuMPmodel
    @test !(:params in keys(j_model.ext))
    @test JuMP.num_variables(j_model) == 120
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 24
    @test !((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(j_model))
    @test JuMP.objective_function_type(j_model) == JuMP.GenericQuadExpr{Float64, VariableRef}

    op_model = OperationModel(TestOptModel, model_ref,
                                            c_sys5_re;
                                            forecast = false,
                                            optimizer = GLPK_optimizer)
    j_model = op_model.canonical.JuMPmodel
    @test !(:params in keys(j_model.ext))
    @test JuMP.num_variables(j_model) == 5
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 5
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 1
    @test !((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(j_model))
    @test JuMP.objective_function_type(j_model) == JuMP.GenericAffExpr{Float64, VariableRef}

    op_model = OperationModel(TestOptModel, model_ref,
                                            c_sys5_re;
                                            forecast = false,
                                            parameters = false,
                                            optimizer = GLPK_optimizer)
    j_model = op_model.canonical.JuMPmodel
    @test !(:params in keys(j_model.ext))
    @test JuMP.num_variables(j_model) == 5
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.Interval{Float64}) == 5
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(j_model, JuMP.GenericAffExpr{Float64, VariableRef}, MOI.EqualTo{Float64}) == 1
    @test !((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(j_model))
    @test JuMP.objective_function_type(j_model) == JuMP.GenericAffExpr{Float64, VariableRef}
end


@testset "Operation Model Constructors with Parameters" begin
    networks = [PSI.CopperPlatePowerModel,
                PSI.StandardPTDFForm,
                PM.DCPlosslessForm,
                PM.NFAForm,
                PM.StandardACPForm,
                PM.StandardACRForm,
                PM.StandardACTForm,
                PM.StandardDCPLLForm,
                PM.AbstractLPACCForm,
                PM.SOCWRForm,
                PM.QCWRForm,
                PM.QCWRTriForm];

    thermal_gens = [PSI.ThermalStandardUnitCommitment,
                    PSI.ThermalDispatch,
                    PSI.ThermalRampLimited,
                    PSI.ThermalDispatchNoMin];

        systems = [c_sys5,
                   c_sys5_re,
                   c_sys5_bat];

    for net in networks, thermal in thermal_gens, system in systems, p in [true, false]
        @testset "Operation Model $(net) - $(thermal) - $(system)" begin
            thermal_model = DeviceModel(PSY.ThermalStandard, thermal)
            devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, thermal),
                                                :Loads =>       DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
            branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.StaticLine))
            model_ref = ModelReference(net, devices, branches, services);
            op_model = OperationModel(TestOptModel,
                                      model_ref,
                                      system; PTDF = PTDF5, parameters = p);
        @test :nodal_balance_active in keys(op_model.canonical.expressions)
        @test (:params in keys(op_model.canonical.JuMPmodel.ext)) == p
        end


    end

end

#=
@testset "Build Operation Models" begin
    #SCED = PSI.SCEconomicDispatch(c_sys5; optimizer = GLPK_optimizer);
    #OPF = PSI.OptimalPowerFlow(c_sys5, PM.StandardACPForm, optimizer = ipopt_optimizer)
    #UC = PSI.UnitCommitment(c_sys5, PM.DCPlosslessForm; optimizer = GLPK_optimizer)

    #ED_rts_p = PSI.EconomicDispatch(c_rts, PSI.CopperPlatePowerModel; optimizer = GLPK_optimizer);
    #ED_rts = PSI.EconomicDispatch(c_rts, PSI.CopperPlatePowerModel; optimizer = GLPK_optimizer, parameters = false);
    # These other tests can be enabled when CDM parser get the correct HVDC type.
    #OPF_rts = PSI.OptimalPowerFlow(sys_rts, PSI.CopperPlatePowerModel, optimizer = ipopt_optimizer)
    #UC_rts = PSI.UnitCommitment(sys_rts, PSI.CopperPlatePowerModel; optimizer = GLPK_optimizer, parameters = false)
end

=#
