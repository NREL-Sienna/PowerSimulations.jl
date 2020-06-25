# Power Grid Lib - Unit Commitment / Multi-Start Unit Commitment
This formulation is from the benchmark library maintained by the IEEE PES Task Force on Benchmarks for Validation of Emerging Power System Algorithms and is designed to evaluate a well established version of the the Unit Commitment problem.

# Formulation Overview
 The features of this model are:
- A global load requirement with time series
- An optional global spinning reserve requirement with time series
- Thermal generators with technical parameters, including
  - Minimum and maximum power output
  - Hourly ramp-up and ramp-down rates
  - Start-up and shut-down ramp rates
  - Minimum run-times and off-times
  - Off time dependent start-up costs
  - Piecewise linear convex production costs
  - No-load costs
- Optional renewable generators with time series for minimum and maximum production.


A detailed description of this mathematical model is available [here](https://github.com/power-grid-lib/pglib-uc/blob/master/MODEL.pdf).


# References

[1] Knueven, Bernard, James Ostrowski, and Jean-Paul Watson. "On mixed integer programming formulations for the unit commitment problem." Pre-print available at http://www.optimization-online.org/DB_HTML/2018/11/6930.pdf (2018).

[2] Krall, Eric, Michael Higgins, and Richard P. O’Neill. "RTO unit commitment test system." Federal Energy Regulatory Commission. Available: http://ferc.gov/legal/staff-reports/rto-COMMITMENT-TEST.pdf (2012).
