function _check_constraint_bounds(bounds::PSI.ConstraintBounds, valid_bounds::NamedTuple)
    @test bounds.coefficient.min == valid_bounds.coefficient.min
    @test bounds.coefficient.max == valid_bounds.coefficient.max
    @test bounds.rhs.min == valid_bounds.rhs.min
    @test bounds.rhs.max == valid_bounds.rhs.max
end

function _check_variable_bounds(bounds::PSI.VariableBounds, valid_bounds::NamedTuple)
    @test bounds.bounds.min == valid_bounds.min
    @test bounds.bounds.max == valid_bounds.max
end

@testset "Test Numerical Stability of Constraints" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    valid_bounds =
        (coefficient = (min = 1.0, max = 1.0), rhs = (min = 0.4, max = 9.930296584))
    model = OperationsProblem(template, c_sys5; optimizer = GLPK_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT

    bounds = PSI.get_constraint_numerical_bounds(model; verbose = false)
    _check_constraint_bounds(bounds, valid_bounds)

    model_bounds = PSI.get_constraint_numerical_bounds(model; verbose = true)
    valid_model_bounds = Dict(
        :CopperPlateBalance => (
            coefficient = (min = 1.0, max = 1.0),
            rhs = (min = 6.434489705000001, max = 9.930296584),
        ),
        :P_lb__ThermalStandard__RangeConstraint =>
            (coefficient = (min = 1.0, max = 1.0), rhs = (min = Inf, max = -Inf)),
        :P_ub__ThermalStandard__RangeConstraint =>
            (coefficient = (min = 1.0, max = 1.0), rhs = (min = 0.4, max = 6.0)),
    )
    for (constriant_key, constriant_bounds) in model_bounds
        _check_constraint_bounds(constriant_bounds, valid_model_bounds[constriant_key])
    end
end

@testset "Test Numerical Stability of Variables" begin
    template = get_template_basic_uc_simulation()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc")
    valid_bounds = (min = 0.0, max = 6.0)
    model = OperationsProblem(template, c_sys5; optimizer = GLPK_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT

    bounds = PSI.get_variable_numerical_bounds(model; verbose = false)
    _check_variable_bounds(bounds, valid_bounds)

    model_bounds = PSI.get_variable_numerical_bounds(model; verbose = true)
    valid_model_bounds = Dict(
        :stop__ThermalStandard => (min = 0.0, max = 1.0),
        :start__ThermalStandard => (min = 0.0, max = 1.0),
        :P__ThermalStandard => (min = 0.4, max = 6.0),
        :On__ThermalStandard => (min = 0.0, max = 1.0),
    )
    for (variable_key, variable_bounds) in model_bounds
        _check_variable_bounds(variable_bounds, valid_model_bounds[variable_key])
    end
end
