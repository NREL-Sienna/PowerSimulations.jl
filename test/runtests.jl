using PowerSimulations
using PowerSystems
using PowerModels
using JuMP
using Test
using Ipopt
using GLPK

# required for reducing logging during tests
using Memento

const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations

ipopt_optimizer = with_optimizer(Ipopt.Optimizer, print_level = 0)
GLPK_optimizer = with_optimizer(GLPK.Optimizer)

base_dir = string(dirname(dirname(pathof(PowerSystems))));
include(joinpath(base_dir,"data/data_5bus_pu.jl"));

generators5_uc = [  ThermalDispatch("Alta", true, nodes5[1],
                    TechThermal(0.40, (min=0.0, max=0.40), 0.010, (min = -0.30, max = 0.30), nothing, nothing),
                    EconThermal(0.40, x -> x*14.0, 0.0, 4.0, 2.0, nothing)
                    #EconThermal(40.0, x -> x*14.0, 4.0, 4.0, 2.0, nothing)

                ),
                ThermalDispatch("Park City", true, nodes5[1],
                    TechThermal(1.70, (min=0.0, max=1.70), 0.20, (min =-1.275, max=1.275), (up=0.50, down=0.50), (up=2.0, down=1.0)),
                    EconThermal(1.70, x -> x*15.0, 0.0, 1.5, 0.75, nothing)
                    #EconThermal(170.0, x -> x*15.0, 1.5, 1.5, 0.75, nothing)

                ),
                ThermalDispatch("Solitude", true, nodes5[3],
                    TechThermal(5.20, (min=0.0, max=5.20), 1.00, (min =-3.90, max=3.90), (up=0.520, down=0.520), (up=3.0, down=2.0)),
                    EconThermal(5.20, x -> x*30.0, 0.0, 3.0, 1.5, nothing)
                    #EconThermal(520.0, x -> x*30.0, 3.0, 3.0, 1.5, nothing)

                ),
                ThermalDispatch("Sundance", true, nodes5[4],
                    TechThermal(2.0, (min=0.0, max=2.0), 0.40, (min =-1.5, max=1.5), (up=0.50, down=0.50), (up=2.0, down=1.0)),
                    EconThermal(2.0, x -> x*40.0, 0.0, 4.0, 2.0, nothing)
                    #EconThermal(200.0, x -> x*40.0, 4.0, 4.0, 2.0, nothing)

                ),
                ThermalDispatch("Brighton", true, nodes5[5],
                    TechThermal(6.0, (min=0.0, max=6.0), 1.50, (min =-4.50, max=4.50), (up=0.50, down=0.50), (up=5.0, down=3.0)),
                    #EconThermal(600.0, [(0.0, 0.0), (450.0, 8.0), (600.0, 10.0)], 0.0, 0.0, 0.0, nothing)
                    EconThermal(6.0, x -> x*10.0, 0.0, 0.0, 0.0, nothing)
)
                ];

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

sys5b = PowerSystem(nodes5, vcat(generators5,renewables), loads5_DA, branches5, nothing,  100.0);
sys5b_uc = PowerSystem(nodes5, vcat(generators5_uc,renewables), loads5_DA, branches5, nothing,  100.0);

@testset "Common Functionalities" begin
    include("variables.jl")
    include("constraints.jl")
    include("cost_functions.jl")
    include("PowerModels_interface.jl")
    #include("add_to_expression.jl")
end

@testset "Device Constructors" begin
    include("thermal_generation_constructors.jl")
    include("renewable_generation_constructors.jl")
    include("load_constructors.jl")
    #include("storage_constructors_test.jl")
    #include("HydroConstructors_testing.jl")
end

@testset "Network Constructors" begin
    include("network_constructors.jl")
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

### Daniel Code

LOG_LEVELS = Dict(
    "Debug" => Logging.Debug,
    "Info" => Logging.Info,
    "Warn" => Logging.Warn,
    "Error" => Logging.Error,
)


"""
Copied @includetests from https://github.com/ssfrr/TestSetExtensions.jl.
Ideally, we could import and use TestSetExtensions.  Its functionality was broken by changes
in Julia v0.7.  Refer to https://github.com/ssfrr/TestSetExtensions.jl/pull/7.
"""

"""
Includes the given test files, given as a list without their ".jl" extensions.
If none are given it will scan the directory of the calling file and include all
the julia files.
"""
macro includetests(testarg...)
    if length(testarg) == 0
        tests = []
    elseif length(testarg) == 1
        tests = testarg[1]
    else
        error("@includetests takes zero or one argument")
    end

    quote
        tests = $tests
        rootfile = @__FILE__
        if length(tests) == 0
            tests = readdir(dirname(rootfile))
            tests = filter(f->endswith(f, ".jl") && f != basename(rootfile), tests)
        else
            tests = map(f->string(f, ".jl"), tests)
        end
        println()
        for test in tests
            print(splitext(test)[1], ": ")
            include(test)
            println()
        end
    end
end

gl = global_logger()
level = get(ENV, "PS_LOG_LEVEL", "Error")
log_level = get(LOG_LEVELS, level, nothing)
if log_level == nothing
    error("Invalid log level $level: Supported levels: $(values(LOG_LEVELS))")
end
global_logger(ConsoleLogger(gl.stream, log_level))

# Testing Topological components of the schema
@testset "Begin PowerSystems tests" begin
    @includetests ARGS
end

=#