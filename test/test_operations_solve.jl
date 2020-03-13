import CSV

devices = Dict{Symbol, DeviceModel}(
    :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
)
branches = Dict{Symbol, DeviceModel}(
    :L => DeviceModel(Line, StaticLine),
    :T => DeviceModel(Transformer2W, StaticTransformer),
    :TT => DeviceModel(TapTransformer, StaticTransformer),
)
services = Dict{Symbol, ServiceModel}()

@testset "Solving ED with CopperPlate" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    parameters_value = [true, false]
    systems = [c_sys5, c_sys14]
    test_results = Dict{System, Float64}(c_sys5 => 240000.0, c_sys14 => 142000.0)
    @info "Testing solve ED with CopperPlatePowerModel network"
    for sys in systems, p in parameters_value
        @testset "ED CopperPlatePowerModel model use_parameters = $(p)" begin
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = OSQP_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(ED, [MOI.OPTIMAL], test_results[sys], 10000)

        end
    end
end

@testset "Solving ED with PTDF Models" begin
    template = OperationsProblemTemplate(StandardPTDFModel, devices, branches, services)
    parameters_value = [true, false]
    systems = [c_sys5, c_sys14, c_sys14_dc]
    PTDF_ref =
        Dict{System, PTDF}(c_sys5 => PTDF5, c_sys14 => PTDF14, c_sys14_dc => PTDF14_dc)
    test_results = Dict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    @info "Testing solve ED with StandardPTDFModel network"
    for sys in systems, p in parameters_value
        @testset "ED StandardPTDFModel model use_parameters = $(p)" begin
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = OSQP_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(ED, [MOI.OPTIMAL], test_results[sys], 10000)
        end
    end
end

@testset "Solving ED With PowerModels with loss-less convex models" begin
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters_value = [true, false]
    networks = [DCPPowerModel, NFAPowerModel]
    test_results = Dict{System, Float64}(
        c_sys5 => 330000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    for net in networks, p in parameters_value, sys in systems
        @info("Testing solve ED with $(net) network")
        @testset "ED model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = p,
            )
            #The tolerance range here is large because NFA has a much lower objective value
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[sys],
                35000,
            )
        end
    end

end

@testset "Solving ED With PowerModels with linear convex models" begin
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [DCPLLPowerModel, LPACCPowerModel]
    test_results = Dict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    for net in networks, p in parameters_value, sys in systems
        @info("Testing solve ED with $(net) network")
        @testset "ED model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = p,
            )
            #The tolerance range here is large because NFA has a much lower objective value
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[sys],
                10000,
            )

        end
    end

end

#=
@testset "Solving ED With PowerModels with convex SOC and QC models" begin
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [SOCWRPowerModel,
                 QCRMPowerModel,
                 QCLSPowerModel,]
    test_results = Dict{System, Float64}(c_sys5 => 320000.0,
                                             c_sys14 => 142000.0)
    for  net in networks, p in parameters_value, sys in systems
        @info("Testing solve ED with $(net) network")
        @testset "ED model $(net) and use_parameters = $(p)" begin
        template = OperationsProblemTemplate(net, devices, branches, services);
        ED = OperationsProblem(TestOpProblem, template, sys; optimizer = ipopt_optimizer, use_parameters = p);
        #The tolerance range here is large because Relaxations have a lower objective value
        psi_checksolve_test(ED, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], test_results[sys], 25000)
        end
    end
end
=#

@testset "Solving ED With PowerModels Non-Convex Networks" begin
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters_value = [true, false]
    networks = [
        ACPPowerModel,
        #ACRPowerModel,
        ACTPowerModel,
    ]
    test_results = Dict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    for net in networks, p in parameters_value, sys in systems
        @info("Testing solve ED with $(net) network")
        @testset "ED model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[sys],
                10000,
            )
        end
    end

end

@testset "Solving UC Linear Networks" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    parameters_value = [true, false]
    systems = [c_sys5, c_sys5_dc]
    networks = [DCPPowerModel, NFAPowerModel, StandardPTDFModel, CopperPlatePowerModel]
    PTDF_ref = Dict{System, PTDF}(c_sys5 => PTDF5, c_sys5_dc => PTDF5_dc)

    for net in networks, p in parameters_value, sys in systems
        @info("Testing solve UC with $(net) network")
        @testset "UC model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            UC = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = GLPK_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(UC, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], 340000, 100000)
        end
    end
end
################################################################
duals = [:CopperPlateBalance]
template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services);
op_problem = OperationsProblem(
    TestOpProblem,
    template,
    c_sys5_re;
    optimizer = OSQP_optimizer,
    use_parameters = true,
)
res = solve_op_problem!(op_problem; constraints_duals = duals)

@testset "test constraint duals in the operations problem" begin
    name = PSI.constraint_name("CopperPlateBalance")
    for i in 1:ncol(get_time_stamp(res))
        dual = JuMP.dual(op_problem.psi_container.constraints[name][i])
        @test isapprox(dual, get_duals(res)[name][i, 1])
    end
end

@testset "test get variable function" begin
    @test_throws IS.ConflictingInputsError PSI.get_variable(res, :fake)
    @test res.variable_values[:P__ThermalStandard] ==
          PSI.get_variable(res, :P__ThermalStandard)
end

path = joinpath(pwd(), "test_writing")
!isdir(path) && mkdir(path)

function test_write_functions(file_path)

    @testset "Test write_data functions" begin
        PSI.write_data(get_variables(res), mkdir(joinpath(file_path, "one")))
        readdir(joinpath(file_path, "one"))
        for (k, v) in get_variables(res)
            @test isfile(joinpath(file_path, "one", "$k.feather"))
        end

        PSI.write_data(
            get_variables(res),
            res.time_stamp,
            mkdir(joinpath(file_path, "two"));
            file_type = CSV,
        )
        for (k, v) in get_variables(res)
            @test isfile(joinpath(file_path, "two/$k.csv"))
        end

        PSI.write_data(
            get_variables(res),
            res.time_stamp,
            mkdir(joinpath(file_path, "three")),
        )
        for (k, v) in get_variables(res)
            @test isfile(joinpath(file_path, "three", "$k.feather"))
        end

        var_name = PSI.variable_name(PSI.ACTIVE_POWER, PSY.ThermalStandard)
        PSI.write_data(
            get_variables(res)[var_name],
            mkdir(joinpath(file_path, "four")),
            string(var_name),
        )
        @test isfile(joinpath(file_path, "four", "$(var_name).feather"))

        #testing if directory is a file
        PSI.write_data(
            get_variables(res)[var_name],
            joinpath(file_path, "four", "$(var_name).feather"),
            string(var_name),
        )
        @test isfile(joinpath(file_path, "four", "$(var_name).feather"))

        PSI.write_optimizer_log(get_optimizer_log(res), mkdir(joinpath(file_path, "five")))
        @test isfile(joinpath(file_path, "five", "optimizer_log.json"))

        PSI.write_to_CSV(res, mkdir(joinpath(file_path, "six")))
        @test !isempty(joinpath(file_path, "six", "results"))
    end

    @testset "Test write result functions" begin
        new_path = joinpath(file_path, "seven")
        PSI.write_results(res, mkdir(new_path))
        @test !isempty(new_path)
    end

    @testset "Test parameter values" begin
        system = op_problem.sys
        params =
            PSI.get_parameter_array(op_problem.psi_container.parameters[:P__get_maxactivepower__PowerLoad])
        params = PSI.axis_array_to_dataframe(params)
        devices = collect(PSY.get_components(PSY.PowerLoad, c_sys5_re))
        multiplier = [PSY.get_activepower(devices[1])]
        for d in 2:length(devices)
            multiplier = hcat(multiplier, PSY.get_activepower(devices[d]))
        end
        extracted = -multiplier .* params
        @test extracted == res.parameter_values[:P_PowerLoad]
    end

    @testset "Set optimizer at solve call" begin
        devices = Dict{Symbol, DeviceModel}(
            :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
            :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
        )
        template = OperationsProblemTemplate(DCPPowerModel, devices, branches, services)
        UC = OperationsProblem(TestOpProblem, template, c_sys5;)
        set_services_template!(
            UC,
            Dict(:Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve)),
        )
        res = solve_op_problem!(UC; optimizer = GLPK_optimizer)
        @test isapprox(get_total_cost(res)[:OBJECTIVE_FUNCTION], 340000.0; atol = 100000.0)
    end
end

try
    test_write_functions(path)
finally
    @info("removing test files")
    rm(path, recursive = true)
end
