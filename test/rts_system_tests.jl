#= @testset "RTS construction test set" begin
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
                PM.QCWRTriForm]

    thermal_gens = [PSI.ThermalUnitCommitment,
                    PSI.ThermalDispatch,
                    PSI.ThermalRampLimited,
                    PSI.ThermalDispatchNoMin]

    systems = [c_sys5,
               c_sys5_re,
               c_sys5_bat];

    renewable_curtailment_model = DeviceModel(PSY.RenewableDispatch, PSI.RenewableConstantPowerFactor)
    thermal_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch)
    hvdc_model = DeviceModel(PSY.HVDCLine, PSI.DCSeriesBranch)
    #hydro = DeviceModel(PSY.HydroDispatch, PSI.HydroDispatch)
    transformer_model = DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch)
    tap_transformer_model = DeviceModel(PSY.TapTransformer, PSI.ACSeriesBranch)
    renewable_fix = DeviceModel(PSY.RenewableFix, PSI.RenewableFixed)
    load_model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
    line_model = DeviceModel(PSY.Line, PSI.ACSeriesBranch)
    bat = DeviceModel(PSY.GenericBattery, PSI.BookKeeping)

    devices = Dict{Symbol, DeviceModel}(:Generators => thermal_model,
                                    :Loads =>  load_model,
                                    :rc => renewable_curtailment_model,
                                    :ren_fix => renewable_fix)
    branches = Dict{Symbol, DeviceModel}(:Lines => line_model,
                                    :HVDC => hvdc_model,
                                    :tap_trafo => tap_transformer_model,
                                    :trafo => transformer_model)
    services = Dict{Symbol, PSI.ServiceModel}()
    net = PSI.CopperPlatePowerModel


    for net in networks, thermal in thermal_gens, system in systems
        @testset "Operation Model $(net) - $(thermal) - $(system)" begin
            thermal_model = DeviceModel(PSY.ThermalStandard, thermal)
            devices = Dict{Symbol, DeviceModel}(:Generators => thermal_model, :Loads =>  load_model)
            branches = Dict{Symbol, DeviceModel}(:Lines => line_model, :Transformer)
            services = Dict{Symbol, PSI.ServiceModel}()
            op_model = OperationModel(TestOptModel, net,
                                        devices,
                                        branches,
                                        services,
                                        system;
                                        parameters = false,
                                        PTDF = PTDF5)
        @test :nodal_balance_active in keys(op_model.canonical_model.expressions)
        @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))
        end


    end

end
=#