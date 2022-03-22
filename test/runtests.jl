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
import Serialization

# Code Quality Tests
import Aqua
Aqua.test_unbound_args(PowerSimulations)
Aqua.test_undefined_exports(PowerSimulations)
Aqua.test_ambiguities(PowerSimulations)

const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder

const PJ = ParameterJuMP
const IS = InfrastructureSystems
const BASE_DIR = string(dirname(dirname(pathof(PowerSimulations))))
const DATA_DIR = joinpath(BASE_DIR, "test/test_data")

include("test_utils/common_operation_model.jl")
include("test_utils/model_checks.jl")
include("test_utils/mock_operation_models.jl")
include("test_utils/solver_definitions.jl")
include("test_utils/operations_problem_templates.jl")

const LOG_FILE = "power-simulations-test.log"

ENV["RUNNING_PSI_TESTS"] = "true"

const DISABLED_TEST_FILES = [
# "test_basic_model_structs.jl",
# "test_device_branch_constructors.jl",
# "test_device_hydro_generation_constructors.jl",
# "test_device_load_constructors.jl",
# "test_device_renewable_generation_constructors.jl",
# "test_device_storage_constructors.jl",
# "test_device_thermal_generation_constructors.jl",
# "test_jump_model_utils.jl",
# "test_model_decision.jl",
# "test_problem_template.jl",
# "test_model_emulation.jl",
# "test_network_constructors.jl",
# "test_services_constructor.jl",
# "test_simulation_models.jl",
# "test_simulation_sequence.jl",
# "test_simulation_build.jl",
# "test_device_hybrid_generation_constructors.jl",
# "test_initialization_problem.jl",
# "test_simulation_execute.jl",
# "test_simulation_results.jl",
# "test_simulation_results_export.jl",
# "test_simulation_store.jl",
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
    if log_level === nothing
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

function get_logging_level_from_env(env_name::String, default)
    level = get(ENV, env_name, default)
    return IS.get_logging_level(level)
end

function run_tests()
    logging_config_filename = get(ENV, "SIIP_LOGGING_CONFIG", nothing)
    if logging_config_filename !== nothing
        config = IS.LoggingConfiguration(logging_config_filename)
    else
        config = IS.LoggingConfiguration(
            filename=LOG_FILE,
            file_level=Logging.Info,
            console_level=Logging.Error,
        )
    end
    console_logger = ConsoleLogger(config.console_stream, config.console_level)

    IS.open_file_logger(LOG_FILE, config.file_level) do file_logger
        levels = (Logging.Info, Logging.Warn, Logging.Error)
        multi_logger =
            IS.MultiLogger([console_logger, file_logger], IS.LogEventTracker(levels))
        global_logger(multi_logger)

        if !isempty(config.group_levels)
            IS.set_group_levels!(multi_logger, config.group_levels)
        end

        @time @testset "Begin PowerSimulations tests" begin
            @includetests ARGS
        end

        @test length(IS.get_log_events(multi_logger.tracker, Logging.Error)) == 0

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
