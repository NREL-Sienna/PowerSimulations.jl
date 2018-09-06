using PowerSystems
using JuMP

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus.jl"))
include(joinpath(base_dir,"data/data_5bus.jl"))

battery = GenericBattery(name = "Bat",
                status = true,
                energy = 10.0,
                realpower = 10.0,
                capacity = (min = 0.0, max = 10.0,),
                inputrealpowerlimit = 10.0,
                outputrealpowerlimit = 10.0,
                efficiency = (in = 0.90, out = 0.80),
                );
sys5b = PowerSystem(nodes5, generators5, loads5_DA, branches5, [battery],  1000.0)
;

m = Model()

PTDF, = PowerSystems.buildptdf(sys.branches, sys.buses)
RHS = BLAS.gemm('N','N', PTDF, timeseries_netinjection)