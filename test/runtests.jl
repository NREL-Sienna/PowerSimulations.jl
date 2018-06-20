using PowerSimulations
using Base.Test

# write your own tests here
@test include("thermalgen_testing.jl")
@test include("network_testing.jl")
