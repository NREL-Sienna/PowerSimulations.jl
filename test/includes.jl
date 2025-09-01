# SIIP Packages
using PowerSimulations
using PowerSystems
using PowerSystemCaseBuilder
using InfrastructureSystems
using PowerNetworkMatrices
using HydroPowerSimulations
import PowerSystemCaseBuilder: PSITestSystems
using PowerNetworkMatrices
using StorageSystemsSimulations
using PowerFlows

# Test Packages
using Test
using Logging

# Dependencies for testing
using PowerModels
using DataFrames
using DataFramesMeta
using Dates
using JuMP
import JuMP.Containers: DenseAxisArray, SparseAxisArray
using TimeSeries
using CSV
import JSON3
using DataStructures
import UUIDs
using Random
import Serialization
import LinearAlgebra

const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder
const PNM = PowerNetworkMatrices

const IS = InfrastructureSystems
const BASE_DIR = string(dirname(dirname(pathof(PowerSimulations))))
const DATA_DIR = joinpath(BASE_DIR, "test/test_data")

include("test_utils/common_operation_model.jl")
include("test_utils/model_checks.jl")
include("test_utils/mock_operation_models.jl")
include("test_utils/solver_definitions.jl")
include("test_utils/operations_problem_templates.jl")

ENV["RUNNING_PSI_TESTS"] = "true"
