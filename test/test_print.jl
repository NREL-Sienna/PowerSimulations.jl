function _test_plain_print_methods(list::Array)
    for object in list
        normal = repr(object)
        io = IOBuffer()
        show(io, "text/plain", object)
        grabbed = String(take!(io))
        @test grabbed !== nothing
    end
end

function _test_html_print_methods(list::Array)
    for object in list
        normal = repr(object)
        io = IOBuffer()
        show(io, "text/html", object)
        grabbed = String(take!(io))
        @test grabbed !== nothing
    end
end



# TODO: Enable for test coverage later
# @testset "Test print methods" begin
#     template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
#     c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
#     model = DecisionModel(
#         MockDecisionProblem,
#         template,
#         c_sys5;
#         optimizer = GLPK_optimizer,
#
#     )
#     list = [template, model, model.container, services]
#     _test_plain_print_methods(list)
#     list = [services]
#     _test_html_print_methods(list)
# end

# TODO: Enable for test coverage later
# @testset "Test print methods" begin
#     list = [sim, sim.sequence, sim.stages["UC"]]
#     _test_plain_print_methods(list)
# end
