abstract type AbstractPowerSimulationParameters
end

"""
PowerOptimizationParameters defines the parameters required for an optimization simulation
"""
struct PowerOptimizationParameters <: AbstractPowerSimulationParameters
    periods::Int
    resolution::Int
    date_from::DateTime
    date_to::DateTime
    lookahead_periods::Int
    lookahead_resolution::Int
end

PowerOptimizationParameters(;
                        periods=1,
                        resolution=1,
                        date_from=DateTime(1970, 1, 1, 0, 0, 0),
                        date_to=DateTime(1970, 1, 1, 0, 0, 0),
                        lookahead_periods=0,
                        lookahead_resolution=0,
                       ) = PowerOptimizationParameters(
                                                       periods,
                                                       resolution,
                                                       date_from,
                                                       date_to,
                                                       lookahead_periods,
                                                       lookahead_resolution,
                                                      )


