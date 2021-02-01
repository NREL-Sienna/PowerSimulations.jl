using Logging
using PowerSimulations
using PowerSystems
using PowerModels
using PowerSystemCaseBuilder
using InfrastructureSystems
using DataFrames
using Dates
using JuMP
using Test
using Ipopt
using GLPK
using Cbc
using OSQP
using SCS
using TimeSeries
using ParameterJuMP
using CSV
using DataFrames
using DataStructures
import UUIDs
import Aqua
import PowerSystemCaseBuilder: PSITestSystems
using Random
Aqua.test_unbound_args(PowerSimulations)
Aqua.test_undefined_exports(PowerSimulations)
#Aqua.test_ambiguities(PowerSimulations)

const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const PJ = ParameterJuMP
const PSB = PowerSystemCaseBuilder
const IS = InfrastructureSystems
TEST_KWARGS = [:good_kwarg_1, :good_kwarg_2]
abstract type TestOpProblem <: PSI.AbstractOperationsProblem end
const BASE_DIR = string(dirname(dirname(pathof(PowerSimulations))))
const DATA_DIR = joinpath(BASE_DIR, "test/test_data")

include("test_utils/model_checks.jl")
include("test_utils/operations_problem_templates.jl")

ipopt_optimizer =
    JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-6, "print_level" => 0)
fast_ipopt_optimizer = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer,
    "print_level" => 0,
    "max_cpu_time" => 5.0,
)
# use default print_level = 5 # set to 0 to disable
GLPK_optimizer =
    JuMP.optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.GLP_MSG_OFF)
Cbc_optimizer = JuMP.optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
OSQP_optimizer =
    JuMP.optimizer_with_attributes(OSQP.Optimizer, "verbose" => false, "max_iter" => 50000)
fast_lp_optimizer =
    JuMP.optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0, "seconds" => 3.0)
scs_solver = JuMP.optimizer_with_attributes(
    SCS.Optimizer,
    "max_iters" => 100000,
    "eps" => 1e-4,
    "verbose" => 0,
)

const LOG_FILE = "power-simulations-test.log"

LOG_LEVELS = Dict(
    "Debug" => Logging.Debug,
    "Info" => Logging.Info,
    "Warn" => Logging.Warn,
    "Error" => Logging.Error,
)

function get_logging_level(env_name::String, default)
    level = get(ENV, env_name, default)
    log_level = get(LOG_LEVELS, level, nothing)
    if isnothing(log_level)
        error("Invalid log level $level: Supported levels: $(values(LOG_LEVELS))")
    end

    return log_level
end

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
            tests = filter(
                f ->
                    startswith(f, "test_") && endswith(f, ".jl") && f != basename(rootfile),
                tests,
            )
        else
            tests = map(f -> string(f, ".jl"), tests)
        end
        println()
        for test in tests
            print(splitext(test)[1], ": ")
            include(test)
            println()
        end
    end
end

function run_tests()
    console_level = get_logging_level("SYS_CONSOLE_LOG_LEVEL", "Error")
    console_logger = ConsoleLogger(stderr, console_level)
    file_level = get_logging_level("SYS_LOG_LEVEL", "Info")

    IS.open_file_logger(LOG_FILE, file_level) do file_logger
        multi_logger = IS.MultiLogger(
            [console_logger, file_logger],
            IS.LogEventTracker((Logging.Info, Logging.Warn, Logging.Error)),
        )
        global_logger(multi_logger)

        @time @testset "Begin PowerSimulations tests" begin
            @includetests ARGS
        end

        # TODO: Enable this once all expected errors are not logged.
        #@test length(IS.get_log_events(multi_logger.tracker, Logging.Error)) == 0

        @info IS.report_log_summary(multi_logger)
    end
end

logger = global_logger()

try
    run_tests()
finally
    # Guarantee that the global logger is reset.
    global_logger(logger)
    nothing
end
