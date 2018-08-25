using PowerSimulations
using Base.Test

# write your own tests here
@test include("network_testing.jl")
@test include("thermalgen_testing.jl")
@test include("renewables_testing.jl")
#@test include("hydro_testing.jl")
#@test include("storage_testing.jl")
#@test include("load_testing.jl")
#@test include("buildED_CN_testing.jl")
#@test include("buildED_NB_testing.jl")

