using TimeSeries
using Dates
using Random
Random.seed!(123)
using PowerSystems

DayAhead = collect(
    DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
        "1/1/2024  23:00:00",
        "d/m/y  H:M:S",
    ),
)
#Dispatch_11am =  collect(DateTime("1/1/2024  0:11:00", "d/m/y  H:M:S"):Minute(15):DateTime("1/1/2024  12::00", "d/m/y  H:M:S"))

nodes5() = [
    Bus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
    Bus(2, "nodeB", "PQ", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
    Bus(3, "nodeC", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
    Bus(4, "nodeD", "REF", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
    Bus(5, "nodeE", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
];

branches5_dc(nodes5) = [
    Line(
        "1",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[2]),
        0.00281,
        0.0281,
        (from = 0.00356, to = 0.00356),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    HVDCLine(
        "DCL2",
        true,
        0.0,
        Arc(from = nodes5[1], to = nodes5[4]),
        (min = -3000.0, max = 3000.0),
        (min = -3000, max = 3000),
        (min = -3000.0, max = 3000.0),
        (min = -3000.0, max = 3000.0),
        (l0 = 0.0, l1 = 0.01),
    ),
    Line(
        "3",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[5]),
        0.00064,
        0.0064,
        (from = 0.01563, to = 0.01563),
        18.8120,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "4",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[2], to = nodes5[3]),
        0.00108,
        0.0108,
        (from = 0.00926, to = 0.00926),
        11.1480,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "5",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[3], to = nodes5[4]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 0.00337),
        40.530,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "6",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[4], to = nodes5[5]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 00.00337),
        2.00,
        (min = -0.7, max = 0.7),
    ),
];

branches5(nodes5) = [
    Line(
        "1",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[2]),
        0.00281,
        0.0281,
        (from = 0.00356, to = 0.00356),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "2",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[4]),
        0.00304,
        0.0304,
        (from = 0.00329, to = 0.00329),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "3",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[5]),
        0.00064,
        0.0064,
        (from = 0.01563, to = 0.01563),
        18.8120,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "4",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[2], to = nodes5[3]),
        0.00108,
        0.0108,
        (from = 0.00926, to = 0.00926),
        11.1480,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "5",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[3], to = nodes5[4]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 0.00337),
        40.530,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "6",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[4], to = nodes5[5]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 00.00337),
        2.00,
        (min = -0.7, max = 0.7),
    ),
];

branches5_ml(nodes5) = [
    MonitoredLine(
        "1",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[2]),
        0.00281,
        0.0281,
        (from = 0.00356, to = 0.00356),
        (from_to = 1.0, to_from = 1.0),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "2",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[4]),
        0.00304,
        0.0304,
        (from = 0.00329, to = 0.00329),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "3",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[5]),
        0.00064,
        0.0064,
        (from = 0.01563, to = 0.01563),
        18.8120,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "4",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[2], to = nodes5[3]),
        0.00108,
        0.0108,
        (from = 0.00926, to = 0.00926),
        11.1480,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "5",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[3], to = nodes5[4]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 0.00337),
        40.530,
        (min = -0.7, max = 0.7),
    ),
    Line(
        "6",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[4], to = nodes5[5]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 00.00337),
        2.00,
        (min = -0.7, max = 0.7),
    ),
];

solar_ts_DA = [
    0
    0
    0
    0
    0
    0
    0
    0
    0
    0.351105684
    0.632536266
    0.99463925
    1
    0.944237283
    0.396681234
    0.366511428
    0.155125829
    0.040872694
    0
    0
    0
    0
    0
    0
]

wind_ts_DA = [
    0.985205412
    0.991791369
    0.997654144
    1
    0.998663733
    0.995497149
    0.992414567
    0.98252418
    0.957203427
    0.927650911
    0.907181989
    0.889095913
    0.848186718
    0.766813846
    0.654052531
    0.525336131
    0.396098004
    0.281771509
    0.197790004
    0.153241012
    0.131355854
    0.113688144
    0.099302656
    0.069569628
]

thermal_generators5(nodes5) = [
    ThermalStandard(
        "Alta",
        true,
        true,
        nodes5[1],
        0.40,
        0.010,
        0.5,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.0, max = 0.40),
        (min = -0.30, max = 0.30),
        nothing,
        nothing,
        ThreePartCost((0.0, 1400.0), 0.0, 4.0, 2.0),
        100.0,
    ),
    ThermalStandard(
        "Park City",
        true,
        true,
        nodes5[1],
        1.70,
        0.20,
        2.2125,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.0, max = 1.70),
        (min = -1.275, max = 1.275),
        (up = 0.02 * 2.2125, down = 0.02 * 2.2125),
        (up = 2.0, down = 1.0),
        ThreePartCost((0.0, 1500.0), 0.0, 1.5, 0.75),
        100.0,
    ),
    ThermalStandard(
        "Solitude",
        true,
        true,
        nodes5[3],
        5.2,
        1.00,
        5.20,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.0, max = 5.20),
        (min = -3.90, max = 3.90),
        (up = 0.012 * 5.2, down = 0.012 * 5.2),
        (up = 3.0, down = 2.0),
        ThreePartCost((0.0, 3000.0), 0.0, 3.0, 1.5),
        100.0,
    ),
    ThermalStandard(
        "Sundance",
        true,
        true,
        nodes5[4],
        2.0,
        0.40,
        2.5,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.0, max = 2.0),
        (min = -1.5, max = 1.5),
        (up = 0.015 * 2.5, down = 0.015 * 2.5),
        (up = 2.0, down = 1.0),
        ThreePartCost((0.0, 4000.0), 0.0, 4.0, 2.0),
        100.0,
    ),
    ThermalStandard(
        "Brighton",
        true,
        true,
        nodes5[5],
        6.0,
        1.50,
        7.5,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.0, max = 6.0),
        (min = -4.50, max = 4.50),
        (up = 0.015 * 7.5, down = 0.015 * 7.5),
        (up = 5.0, down = 3.0),
        ThreePartCost((0.0, 1000.0), 0.0, 1.5, 0.75),
        100.0,
    ),
];

thermal_generators5_pwl(nodes5) = [
    ThermalStandard(
        "Test PWL",
        true,
        true,
        nodes5[1],
        1.70,
        0.20,
        2.2125,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.0, max = 1.70),
        (min = -1.275, max = 1.275),
        (up = 0.02 * 2.2125, down = 0.02 * 2.2125),
        (up = 2.0, down = 1.0),
        ThreePartCost(
            VariableCost([(0.0, 0.5), (290.1, 0.8), (582.72, 1.2), (894.1, 1.70)]),
            0.0,
            1.5,
            0.75,
        ),
        100.0,
    ),
];

thermal_pglib_generators5(nodes5) = [
    ThermalMultiStart(
        "115_STEAM_1",
        true,
        true,
        nodes5[1],
        0.05,
        0.010,
        0.12,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.05, max = 0.12),
        (min = -0.30, max = 0.30),
        (up = 0.2 * 0.12, down = 0.2 * 0.12),
        (startup = 0.05, shutdown = 0.05),
        (up = 4.0, down = 2.0),
        (hot = 2.0, warm = 4.0, cold = 12.0),
        3,
        MultiStartCost(
            VariableCost([(0.0, 0.05), (290.1, 0.0733), (582.72, 0.0967), (894.1, 0.120)]),
            897.29,
            0.0,
            (hot = 393.28, warm = 455.37, cold = 703.76),
            0.0,
        ),
        100.0,
    ),
    ThermalMultiStart(
        "101_CT_1",
        true,
        true,
        nodes5[1],
        0.08,
        0.020,
        0.12,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.08, max = 0.20),
        (min = -0.30, max = 0.30),
        (up = 0.2 * 0.12, down = 0.2 * 0.12),
        (startup = 0.08, shutdown = 0.08),
        (up = 1.0, down = 1.0),
        (hot = 1.0, warm = 999.0, cold = 999.0),
        1,
        MultiStartCost(
            VariableCost([(0.0, 0.08), (391.45, 0.012), (783.74, 0.016), (1212.28, 0.20)]),
            1085.78,
            0.0,
            (hot = 51.75, warm = PSY.START_COST, cold = PSY.START_COST),
            0.0,
        ),
        100.0,
    ),
];

renewable_generators5(nodes5) = [
    RenewableDispatch(
        "WindBusA",
        true,
        nodes5[5],
        0.0,
        0.0,
        1.200,
        PrimeMovers.WT,
        (min = 0.0, max = 0.0),
        1.0,
        TwoPartCost(22.0, 0.0),
        100.0,
    ),
    RenewableDispatch(
        "WindBusB",
        true,
        nodes5[4],
        0.0,
        0.0,
        1.200,
        PrimeMovers.WT,
        (min = 0.0, max = 0.0),
        1.0,
        TwoPartCost(22.0, 0.0),
        100.0,
    ),
    RenewableDispatch(
        "WindBusC",
        true,
        nodes5[3],
        0.0,
        0.0,
        1.20,
        PrimeMovers.WT,
        (min = -0.800, max = 0.800),
        1.0,
        TwoPartCost(22.0, 0.0),
        100.0,
    ),
];

hydro_generators5(nodes5) = [
    HydroDispatch(
        "HydroDispatch",
        true,
        nodes5[2],
        0.0,
        0.0,
        0.6,
        PrimeMovers.HY,
        (min = 0.1, max = 3.0),
        (min = 0.1, max = 3.0),
        nothing,
        nothing,
        100.0,
    ),
    HydroEnergyReservoir(
        "HydroEnergyReservoir",
        true,
        nodes5[3],
        0.0,
        0.0,
        0.6,
        PrimeMovers.HY,
        (min = 0.0, max = 60.0),
        (min = 0.0, max = 60.0),
        (up = 10.0 * 0.6, down = 10.0 * 0.6),
        nothing,
        TwoPartCost(15.0, 0.0),
        100.0,
        1.0,
        0.2,
        0.5,
    ),
];

battery5(nodes5) = [GenericBattery(
    name = "Bat",
    prime_mover = PrimeMovers.BA,
    available = true,
    bus = nodes5[1],
    initial_energy = 5.0,
    state_of_charge_limits = (min = 5.0, max = 100.0),
    rating = 70.0,
    active_power = 10.0,
    input_active_power_limits = (min = 0.0, max = 50.0),
    output_active_power_limits = (min = 0.0, max = 50.0),
    efficiency = (in = 0.80, out = 0.90),
    reactive_power = 0.0,
    reactive_power_limits = (min = -50.0, max = 50.0),
    base_power = 100.0,
)];

loadbus2_ts_DA = [
    0.792729978
    0.723201574
    0.710952098
    0.677672816
    0.668249175
    0.67166919
    0.687608809
    0.711821241
    0.756320618
    0.7984057
    0.827836527
    0.840362459
    0.84511032
    0.834592803
    0.822949221
    0.816941743
    0.824079963
    0.905735139
    0.989967048
    1
    0.991227765
    0.960842114
    0.921465115
    0.837001437
]

loadbus3_ts_DA = [
    0.831093782
    0.689863228
    0.666058513
    0.627033103
    0.624901388
    0.62858924
    0.650734211
    0.683424321
    0.750876413
    0.828347191
    0.884248576
    0.888523615
    0.87752169
    0.847534405
    0.8227661
    0.803809323
    0.813282799
    0.907575962
    0.98679848
    1
    0.990489904
    0.952520972
    0.906611479
    0.824307054
]

loadbus4_ts_DA = [
    0.871297342
    0.670489749
    0.642812243
    0.630092987
    0.652991383
    0.671971681
    0.716278493
    0.770885833
    0.810075243
    0.85562361
    0.892440566
    0.910660449
    0.922135467
    0.898416969
    0.879816542
    0.896390855
    0.978598576
    0.96523761
    1
    0.969626503
    0.901212601
    0.81894251
    0.771004923
    0.717847996
]

loads5(nodes5) = [
    PowerLoad(
        "Bus2",
        true,
        nodes5[2],
        LoadModels.ConstantPower,
        3.0,
        0.9861,
        100.0,
        3.0,
        0.9861,
    ),
    PowerLoad(
        "Bus3",
        true,
        nodes5[3],
        LoadModels.ConstantPower,
        3.0,
        0.9861,
        100.0,
        3.0,
        0.9861,
    ),
    PowerLoad(
        "Bus4",
        true,
        nodes5[4],
        LoadModels.ConstantPower,
        4.0,
        1.3147,
        100.0,
        4.0,
        1.3147,
    ),
];

interruptible(nodes5) = [InterruptibleLoad(
    "IloadBus4",
    true,
    nodes5[4],
    LoadModels.ConstantPower,
    0.10,
    0.0,
    0.10,
    0.0,
    100.0,
    TwoPartCost(150.0, 2400.0),
)]

ORDC_cost =
    TwoPartCost([(9000.0, 0.0), (6000.0, 0.2), (500.0, 0.4), (10.0, 0.6), (0.0, 0.8)], 0.0)

reserve5(thermal_generators5) = [
    VariableReserve{ReserveUp}(
        "Reserve1",
        true,
        0.6,
        maximum([gen.active_power_limits[:max] for gen in thermal_generators5]) .* 0.001,
    ),
    VariableReserve{ReserveDown}(
        "Reserve2",
        true,
        0.3,
        maximum([gen.active_power_limits[:max] for gen in thermal_generators5]) .* 0.005,
    ),
    VariableReserve{ReserveUp}(
        "Reserve11",
        true,
        0.8,
        maximum([gen.active_power_limits[:max] for gen in thermal_generators5]) .* 0.001,
    ),
    ReserveDemandCurve{ReserveUp}("ORDC1", true, 0.6, ORDC_cost),
]

reserve5_re(renewable_generators5) = [
    VariableReserve{ReserveUp}("Reserve3", true, 30, 100),
    VariableReserve{ReserveDown}("Reserve4", true, 5, 50),
    ReserveDemandCurve{ReserveUp}("ORDC2", true, 0.6, ORDC_cost),
]
reserve5_hy(hydro_generators5) = [
    VariableReserve{ReserveUp}("Reserve5", true, 30, 100),
    VariableReserve{ReserveDown}("Reserve6", true, 5, 50),
    ReserveDemandCurve{ReserveUp}("ORDC3", true, 0.6, ORDC_cost),
]

reserve5_il(interruptible_loads) = [
    VariableReserve{ReserveUp}("Reserve7", true, 30, 100),
    VariableReserve{ReserveDown}("Reserve8", true, 5, 50),
    ReserveDemandCurve{ReserveUp}("ORDC3", true, 0.6, ORDC_cost),
]

function make_ordc_cost(cost::TwoPartCost)
    var_cost = PSY.get_cost(PSY.get_variable(cost))
    flatten_array = Array(collect(Iterators.flatten(var_cost))')
    name = collect(Iterators.flatten([
        (Symbol("cost_bp$(ix)"), Symbol("load_bp$ix")) for ix in 1:length(var_cost)
    ]))
    return flatten_array, name
end

data_array, col_names = make_ordc_cost(ORDC_cost)
ORDC_cost_ts = [
    TimeArray(DayAhead, repeat(data_array, 24), col_names),
    TimeArray(DayAhead + Day(1), repeat(data_array, 24), col_names),
]

Reserve_ts = [TimeArray(DayAhead, rand(24)), TimeArray(DayAhead + Day(1), rand(24))]

hydro_timeseries_DA = [
    [TimeSeries.TimeArray(DayAhead, wind_ts_DA)],
    [TimeSeries.TimeArray(DayAhead + Day(1), wind_ts_DA)],
];

RealTime = collect(
    DateTime("1/1/2024 0:00:00", "d/m/y H:M:S"):Minute(5):DateTime(
        "1/1/2024 23:55:00",
        "d/m/y H:M:S",
    ),
)

hydro_timeseries_RT = [
    [TimeArray(RealTime, repeat(wind_ts_DA, inner = 12))],
    [TimeArray(RealTime + Day(1), repeat(wind_ts_DA, inner = 12))],
];

load_timeseries_RT = [
    [
        TimeArray(RealTime, repeat(loadbus2_ts_DA, inner = 12)),
        TimeArray(RealTime, repeat(loadbus3_ts_DA, inner = 12)),
        TimeArray(RealTime, repeat(loadbus4_ts_DA, inner = 12)),
    ],
    [
        TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(loadbus2_ts_DA, inner = 12)),
        TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(loadbus3_ts_DA, inner = 12)),
        TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(loadbus4_ts_DA, inner = 12)),
    ],
]

ren_timeseries_RT = [
    [
        TimeArray(RealTime, repeat(solar_ts_DA, inner = 12)),
        TimeArray(RealTime, repeat(wind_ts_DA, inner = 12)),
        TimeArray(RealTime, repeat(wind_ts_DA, inner = 12)),
    ],
    [
        TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(solar_ts_DA, inner = 12)),
        TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(wind_ts_DA, inner = 12)),
        TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(wind_ts_DA, inner = 12)),
    ],
]

Iload_timeseries_RT = [
    [TimeArray(RealTime, repeat(loadbus4_ts_DA, inner = 12))],
    [TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(loadbus4_ts_DA, inner = 12))],
]

load_timeseries_DA = [
    [
        TimeSeries.TimeArray(DayAhead, loadbus2_ts_DA),
        TimeSeries.TimeArray(DayAhead, loadbus3_ts_DA),
        TimeSeries.TimeArray(DayAhead, loadbus4_ts_DA),
    ],
    [
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + loadbus2_ts_DA),
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + loadbus3_ts_DA),
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + loadbus4_ts_DA),
    ],
];

ren_timeseries_DA = [
    [
        TimeSeries.TimeArray(DayAhead, solar_ts_DA),
        TimeSeries.TimeArray(DayAhead, wind_ts_DA),
        TimeSeries.TimeArray(DayAhead, wind_ts_DA),
    ],
    [
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + solar_ts_DA),
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + wind_ts_DA),
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + wind_ts_DA),
    ],
];

Iload_timeseries_DA = [
    [TimeArray(DayAhead, loadbus4_ts_DA)],
    [TimeArray(DayAhead + Day(1), loadbus4_ts_DA + 0.1 * rand(24))],
]
