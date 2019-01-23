using PowerSimulations
using PowerSystems
using PowerModels
using JuMP
using Test
using InfrastructureModels
using Ipopt

# required for reducing logging during tests
using Memento

const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations

base_dir = string(dirname(dirname(pathof(PowerSystems))));
include(joinpath(base_dir,"data/data_5bus_pu.jl"));

renewables = [RenewableCurtailment("WindBusA", true, nodes5[5],
            120.0,
            EconRenewable(22.0, nothing),
            TimeSeries.TimeArray(DayAhead,wind_ts_DA)
            ),
            RenewableCurtailment("WindBusB", true, nodes5[4],
            120.0,
            EconRenewable(22.0, nothing),
            TimeSeries.TimeArray(DayAhead,wind_ts_DA)
            ),
            RenewableCurtailment("WindBusC", true, nodes5[3],
            120.0,
            EconRenewable(22.0, nothing),
            TimeSeries.TimeArray(DayAhead,wind_ts_DA)
            )];

battery = [GenericBattery(name = "Bat",
                status = true,
                bus = nodes5[1],
                activepower = 10.0,
                energy = 5.0,
                capacity = (min = 0.0, max = 0.0),
                inputactivepowerlimits = (min = 0.0, max = 50.0),
                outputactivepowerlimits = (min = 0.0, max = 50.0),
                efficiency = (in = 0.90, out = 0.80),
                )];

generators_hg = [
    HydroFix("HydroFix",true,nodes5[2],
        TechHydro(0.600, 0.150, (min = 0.0, max = 60.0), 0.0, (min = 0.0, max = 60.0), nothing, nothing),
        TimeSeries.TimeArray(DayAhead,solar_ts_DA)
    ),
    HydroCurtailment("HydroCurtailment",true,nodes5[3],
        TechHydro(0.600, 0.100, (min = 0.0, max = 60.0), 0.0, (min = 0.0, max = 60.0), (up = 10.0, down = 10.0), nothing),
        100.0,TimeSeries.TimeArray(DayAhead,wind_ts_DA) )
];

@testset "Common Functionalities" begin
    include("variables_testing.jl")
    include("constraints_testing.jl")
    include("costfunction_testing.jl")
end

@testset "Device Constructors" begin
    include("ThermalConstructors_testing.jl")
    #include("RenewableConstructors_testing.jl")
    #include("LoadsConstructors_testing.jl")
    #include("HydroConstructors_testing.jl")
end

@testset "Network Constructors" begin
    include("powermodels_testing.jl")
    #include("network_testing.jl")
end

#=
@testset "Services Constructors" begin
    include("service_testing.jl")
end

@testset "Model Constructors" begin
    include("model_testing.jl")
    #include("model_solve_testing.jl")
    #include("buildED_CN_testing.jl")
    #include("buildED_NB_testing.jl")
end

@testset "Simulation routines" begin
    include("simulations_testing.jl")
end
=#