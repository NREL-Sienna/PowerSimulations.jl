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
        template_dcp = ProblemTemplate(DCPPowerModel)
        template_default = ProblemTemplate()
        
        # 2. NetworkModel construction for common network types
        # These create the internal data structures used throughout
        network_copper = NetworkModel(CopperPlatePowerModel)
        network_ptdf = NetworkModel(PTDFPowerModel)
        network_dcp = NetworkModel(DCPPowerModel)
        network_area = NetworkModel(AreaBalancePowerModel)
        network_area_ptdf = NetworkModel(AreaPTDFPowerModel)
        
        # 3. Chronology objects - used in all simulations
        inter_chron = InterProblemChronology()
        intra_chron = IntraProblemChronology()
        
        # 4. Basic operations on templates to trigger more compilation
        Base.isempty(template_default)
        Base.isempty(template_copper)
        Base.isempty(template_ptdf)
        
        # 5. NetworkModel getters - frequently called
        get_network_formulation(network_copper)
        get_network_formulation(network_ptdf)
        get_network_formulation(network_dcp)
        
    catch e
        # Silently catch errors to prevent precompilation failures
        # during package installation or updates
    end
end

# Explicit precompile directives for common method signatures
# These complement the workload above by explicitly requesting compilation
# of specific method signatures that are frequently used

# Template constructors - cover all common network formulations
for T in [CopperPlatePowerModel, PTDFPowerModel, DCPPowerModel, ACPPowerModel,
          AreaBalancePowerModel, AreaPTDFPowerModel]
    precompile(Tuple{Type{ProblemTemplate}, Type{T}})
    precompile(Tuple{Type{NetworkModel}, Type{T}})
    precompile(Tuple{Type{ProblemTemplate}, NetworkModel{T}})
end

# Default constructor
precompile(Tuple{Type{ProblemTemplate}})

# Chronology constructors
precompile(Tuple{Type{InterProblemChronology}})
precompile(Tuple{Type{IntraProblemChronology}})

# Common utility functions on templates
precompile(Tuple{typeof(Base.isempty), ProblemTemplate})
precompile(Tuple{typeof(get_network_formulation), NetworkModel{CopperPlatePowerModel}})
precompile(Tuple{typeof(get_network_formulation), NetworkModel{PTDFPowerModel}})
precompile(Tuple{typeof(get_network_formulation), NetworkModel{DCPPowerModel}})

# Container initialization patterns - these are called during build!
# Note: We can't precompile the full build! without system data, but we can
# precompile the container setup functions
precompile(Tuple{Type{DevicesModelContainer}})
precompile(Tuple{Type{ServicesModelContainer}})
