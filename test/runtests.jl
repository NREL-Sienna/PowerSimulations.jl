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

abstract type TestOptModel <: PSI.AbstractOperationsModel end

ipopt_optimizer = with_optimizer(Ipopt.Optimizer, print_level = 0)
GLPK_optimizer = with_optimizer(GLPK.Optimizer)

base_dir = string(dirname(dirname(pathof(PowerSystems))));
include(joinpath(base_dir,"data/data_5bus_pu.jl"));
bus_numbers = [b.number for b in nodes5]

include(joinpath(base_dir,"data/data_14bus_pu.jl"))
sys14 = PowerSystem(nodes14, generators14, loads14, branches14, nothing,  100.0);

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
sys5b_uc = PowerSystem(nodes5, generators5_uc, loads5_DA, branches5, nothing,  100.0);
sys5b_storage = PowerSystem(nodes5, vcat(generators5_uc,renewables), loads5_DA, branches5, battery,  100.0);

time_range = 1:sys5b.time_periods


@testset "Common Functionalities" begin
    #include("PowerModels_interface.jl")
end

@testset "Device Constructors" begin
    #include("thermal_generation_constructors.jl")
    #include("renewable_generation_constructors.jl")
    #include("load_constructors.jl")
    #include("storage_constructors.jl")
    #include("hydro_generation_constructors.jl")
end

@testset "Network Constructors" begin
    include("network_constructors.jl")
end

@testset "Services Constructors" begin
    #include("services_constructor.jl")
end

@testset "Operation Models" begin
    include("operation_model_constructor.jl")
    include("operation_model_solve.jl")
end
