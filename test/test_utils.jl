@testset "kwarg check" begin
    function mock_constructor(args...; kwargs...)
        PowerSimulations.check_kwargs(kwargs, TEST_KWARGS, "mock")
        return args
    end
    @test (10, 11) == mock_constructor(10, 11; good_kwarg_1 = 43)
    @test_throws ArgumentError mock_constructor(10; bad_kwarg_1 = 43)
end
