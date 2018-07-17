using PowerSimulations
using Base.Test

# write your own tests here
@test include("network_testing.jl")
@test include("thermalgen_testing.jl")
@test include("renewables_testing.jl")
@test include("hydro_testing.jl")
@test include("storage_testing.jl")
@test include("load_testing.jl")
@test include("buildEC_testing.jl")

