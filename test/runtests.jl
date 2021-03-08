# SIIP Packages
using PowerSimulations
using PowerSystems
using PowerSystemCaseBuilder
using InfrastructureSystems
import PowerSystemCaseBuilder: PSITestSystems

# Test Packages
using Test
using Logging

# Dependencies for testing
using PowerModels
using DataFrames
using Dates
using JuMP
using TimeSeries
using ParameterJuMP
using CSV
using DataFrames
using DataStructures
import UUIDs
using Random

# Solvers
using Ipopt
using GLPK
using Cbc
using OSQP
using SCS

# Code Quality Tests
import Aqua
Aqua.test_unbound_args(PowerSimulations)
Aqua.test_undefined_exports(PowerSimulations)
#Aqua.test_ambiguities(PowerSimulations)

const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder

const PJ = ParameterJuMP
const IS = InfrastructureSystems
const BASE_DIR = string(dirname(dirname(pathof(PowerSimulations))))
const DATA_DIR = joinpath(BASE_DIR, "test/test_data")

include("test_utils/model_checks.jl")
include("test_utils/mock_operation_models.jl")
include("test_utils/solver_definitions.jl")
include("test_utils/operations_problem_templates.jl")

const LOG_FILE = "power-simulations-test.log"

const DISABLED_TEST_FILES = [
    "test_device_thermal_generation_constructors.jl",
    "test_device_branch_constructors.jl",
    "test_simulation_build.jl",
    "test_simulation_execute.jl",
]

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
        if !isempty(DISABLED_TEST_FILES)
            @warn("Some tests are disabled $DISABLED_TEST_FILES")
        end
        for test in tests
            test ∈ DISABLED_TEST_FILES && continue
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
