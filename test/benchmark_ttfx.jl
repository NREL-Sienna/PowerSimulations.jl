#!/usr/bin/env julia
"""
Benchmark script to demonstrate TTFX improvements from precompilation.

Run this script to measure the time it takes to execute common operations
on first use vs. second use.
"""

println("="^80)
println("PowerSimulations.jl TTFX Benchmark")
println("="^80)
println()

println("Loading package...")
@time using PowerSimulations
println()

println("="^80)
println("First execution (with precompilation benefits):")
println("="^80)
println()

println("Creating ProblemTemplate()...")
@time t1 = ProblemTemplate()

println("Creating ProblemTemplate(PTDFPowerModel)...")
@time t2 = ProblemTemplate(PTDFPowerModel)

println("Creating ProblemTemplate(CopperPlatePowerModel)...")
@time t3 = ProblemTemplate(CopperPlatePowerModel)

println("Creating NetworkModel(DCPPowerModel)...")
@time nm1 = NetworkModel(DCPPowerModel)

println("Creating InterProblemChronology()...")
@time c1 = InterProblemChronology()

println()
println("="^80)
println("Second execution (shows baseline performance):")
println("="^80)
println()

println("Creating ProblemTemplate()...")
@time t1b = ProblemTemplate()

println("Creating ProblemTemplate(PTDFPowerModel)...")
@time t2b = ProblemTemplate(PTDFPowerModel)

println("Creating ProblemTemplate(CopperPlatePowerModel)...")
@time t3b = ProblemTemplate(CopperPlatePowerModel)

println("Creating NetworkModel(DCPPowerModel)...")
@time nm1b = NetworkModel(DCPPowerModel)

println("Creating InterProblemChronology()...")
@time c1b = InterProblemChronology()

println()
println("="^80)
println("Summary:")
println("="^80)
println("If precompilation is working correctly, the first execution times")
println("should be similar to or only slightly slower than the second execution.")
println("Without precompilation, the first execution would show significant")
println("compilation overhead (tens of milliseconds or more).")
println("="^80)
