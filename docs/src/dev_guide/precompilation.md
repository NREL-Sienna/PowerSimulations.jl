# Precompilation and Time-To-First-Execution (TTFX)

This document explains the precompilation strategy used in PowerSimulations.jl to reduce Time-To-First-Execution (TTFX).

## Background

PowerSimulations.jl is a large package with complex type hierarchies and many method specializations. When users first call functions like `build!` after loading the package, Julia must compile specialized versions of these methods for the specific types being used. This compilation can take significant time (historically 30-50 seconds for the first `build!` call vs. ~2-3 seconds for subsequent calls).

## Precompilation Strategy

We use [PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl) to reduce TTFX by executing common code paths during package precompilation. The precompilation workload is defined in `src/precompile.jl`.

### What Gets Precompiled

The precompilation workload focuses on:

1. **Template Construction**: Creating `ProblemTemplate` objects with various network formulations (CopperPlate, PTDF, DCP, ACP, etc.)
2. **NetworkModel Construction**: Building network models for common formulations
3. **Common Operations**: Basic operations that are always executed regardless of the specific problem being solved

### What Doesn't Get Precompiled

Full simulation builds require PowerSystems data, which is not available during package precompilation. Therefore, we cannot precompile:

- The full `build!` workflow
- Device-specific model construction (requires actual system components)
- Optimization problem assembly (requires system-specific data)

However, by precompiling the setup and configuration steps, we significantly reduce the compilation time for these operations.

## Adding New Precompilation Workloads

If you add new commonly-used types or functions, consider adding them to the precompilation workload:

1. **Lightweight Operations**: Add to the `@compile_workload` block in `src/precompile.jl`
   ```julia
   try
       new_common_operation()
   catch e
       # Silently ignore errors
   end
   ```

2. **Explicit Precompile Directives**: For specific method signatures
   ```julia
   precompile(Tuple{typeof(my_function), ArgType1, ArgType2})
   ```

### Guidelines

- Keep precompilation workloads lightweight - avoid expensive computations
- Always wrap in try-catch to prevent precompilation failures
- Focus on type construction and method dispatch, not actual data processing
- Test that new workloads don't significantly increase package precompile time

## Measuring TTFX

To measure the improvement from precompilation:

```julia
# Start fresh Julia session
using PowerSimulations

# First execution (benefits from precompilation)
@time template = ProblemTemplate(PTDFPowerModel)

# Second execution (shows baseline performance)
@time template2 = ProblemTemplate(PTDFPowerModel)
```

For full build measurements, see the performance test in `test/performance/performance_test.jl`.

## References

- [Julia Precompilation Tutorial](https://julialang.org/blog/2021/01/precompile_tutorial/)
- [PrecompileTools.jl Documentation](https://julialang.github.io/PrecompileTools.jl/stable/)
