"""
Abstract type for all optimizers
"""
abstract type AbstractOptimizer <: AbstractApiType end

"""
CBC optimizer
"""
mutable struct CBC <: AbstractOptimizer
    type::String
end
CBC(; type="CBC") = CBC(type)
StructTypes.StructType(::Type{CBC}) = StructTypes.Mutable()

"""
CPLEX optimizer
"""
mutable struct CPLEX <: AbstractOptimizer
    type::String
end
CPLEX(; type="CPLEX") = CPLEX(type)
StructTypes.StructType(::Type{CPLEX}) = StructTypes.Mutable()

"""
GLPK optimizer
"""
mutable struct GLPK <: AbstractOptimizer
    type::String
    msg_lev::Int
end

GLPK(; msg_level=0, type="GLPK") = GLPK(type, msg_level)

StructTypes.StructType(::Type{GLPK}) = StructTypes.Mutable()


"""
Gurobi optimizer
"""
mutable struct Gurobi <: AbstractOptimizer
    type::String
end
Gurobi(; type="Gurobi") = Gurobi(type)
StructTypes.StructType(::Type{Gurobi}) = StructTypes.Mutable()

"""
HiGHS optimizer
"""
mutable struct HiGHS <: AbstractOptimizer
    type::String
    time_limit::Float64
    log_to_console::Bool
end

HiGHS(; time_limit=100.0, log_to_console=false, type="HiGHS") =
    HiGHS(type, time_limit, log_to_console)

StructTypes.StructType(::Type{HiGHS}) = StructTypes.Mutable()

"""
IPOPT optimizer
"""
mutable struct Ipopt <: AbstractOptimizer
    type::String
    print_level::Int
    max_cpu_time::Float64
end

Ipopt(; print_level=0, max_cpu_time=5.0, type="Ipopt") =
    Ipopt(type, print_level, max_cpu_time)

StructTypes.StructType(::Type{Ipopt}) = StructTypes.Mutable()

"""
SCS optimizer
"""
mutable struct SCS <: AbstractOptimizer
    type::String
    max_iters::Int
    eps::Float64
    verbose::Int
end

SCS(; max_iters=100000, eps=1e-4, verbose=0, type="SCS") =
    SCS(type, max_iters, eps, verbose)

StructTypes.StructType(::Type{SCS}) = StructTypes.Mutable()

"""
Xpress optimizer
"""
mutable struct Xpress <: AbstractOptimizer
    type::String
end
Xpress(; type="Xpress") = Xpress(type)
StructTypes.StructType(::Type{Xpress}) = StructTypes.Mutable()

StructTypes.StructType(::Type{AbstractOptimizer}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{AbstractOptimizer}) = :type
StructTypes.subtypes(::Type{AbstractOptimizer}) = (
    CBC=CBC,
    CPLEX=CPLEX,
    GLPK=GLPK,
    Gurobi=Gurobi,
    HiGHS=HiGHS,
    Ipopt=Ipopt,
    SCS=SCS,
    Xpress=Xpress,
)
