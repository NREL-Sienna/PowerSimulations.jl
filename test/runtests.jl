using PowerSimulations
using Test


@testset "Device Constructors" begin
    include("thermalgen_testing.jl")
    include("renewables_testing.jl")
    include("load_testing.jl")
    #include("hydro_testing.jl")
    #include("storage_testing.jl")
end

@testset "Network Constructors" begin
    include("powermodels_testing.jl")
    include("network_testing.jl")
end

@testset "Services Constructors" begin
    include("service_testing.jl")
end

@testset "Model Constructors" begin
    include("model_testing.jl")
    #include("model_solve_testing.jl")
    #include("buildED_CN_testing.jl")
    #include("buildED_NB_testing.jl")
end