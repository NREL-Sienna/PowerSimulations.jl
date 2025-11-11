"""
    Precompilation workload for PowerSimulations.jl

This file contains representative workloads to reduce time-to-first-execution (TTFX).
We use PrecompileTools to execute common code paths during package precompilation.
"""

import PrecompileTools

PrecompileTools.@compile_workload begin
    # Execute common workflows to precompile method specializations
    # We focus on type construction and basic template operations that don't require system data
    
    try
        # 1. Template construction - most common user entry point
        template_copper = ProblemTemplate(CopperPlatePowerModel)
        template_ptdf = ProblemTemplate(PTDFPowerModel)
        template_default = ProblemTemplate()
        
        # 2. NetworkModel construction for common network types
        # These create the internal data structures used throughout
        network_copper = NetworkModel(CopperPlatePowerModel)
        network_ptdf = NetworkModel(PTDFPowerModel)
        network_area = NetworkModel(AreaBalancePowerModel)
        
        # 3. Chronology objects - used in all simulations
        inter_chron = InterProblemChronology()
        intra_chron = IntraProblemChronology()
        
        # 4. Basic operations on templates
        # These trigger compilations of container management code
        Base.isempty(template_default)
        Base.isempty(template_copper)
        
    catch e
        # Silently catch errors to prevent precompilation failures
        # during package installation or updates
    end
end

# Explicit precompile directives for common method signatures
# These complement the workload above by explicitly requesting compilation
# of specific method signatures that are frequently used

# Template constructors
precompile(Tuple{Type{ProblemTemplate}})
precompile(Tuple{Type{ProblemTemplate}, Type{CopperPlatePowerModel}})
precompile(Tuple{Type{ProblemTemplate}, Type{PTDFPowerModel}})
precompile(Tuple{Type{ProblemTemplate}, Type{DCPPowerModel}})
precompile(Tuple{Type{ProblemTemplate}, NetworkModel{CopperPlatePowerModel}})
precompile(Tuple{Type{ProblemTemplate}, NetworkModel{PTDFPowerModel}})

# NetworkModel constructors for common types
precompile(Tuple{Type{NetworkModel}, Type{CopperPlatePowerModel}})
precompile(Tuple{Type{NetworkModel}, Type{PTDFPowerModel}})
precompile(Tuple{Type{NetworkModel}, Type{DCPPowerModel}})
precompile(Tuple{Type{NetworkModel}, Type{AreaBalancePowerModel}})
precompile(Tuple{Type{NetworkModel}, Type{AreaPTDFPowerModel}})

# Chronology constructors
precompile(Tuple{Type{InterProblemChronology}})
precompile(Tuple{Type{IntraProblemChronology}})

# Common utility functions on templates
precompile(Tuple{typeof(Base.isempty), ProblemTemplate})
