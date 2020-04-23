using Documenter
using PowerSimulations

makedocs(
    sitename = "PowerSimulations.jl",
    format = Documenter.HTML(mathengine = Documenter.MathJax()),
    modules = [PowerSimulations],
    strict = true,
    authors = "Jose Daniel Lara, Clayton Barrows and Dheepak Krishnamurthy",
    pages = Any[
        "Introduction" => "index.md",
        #"Quick Start Guide" => "qs_guide.md",
        "Logging" => "man/logging.md",
        "Operation Model" => "man/op_problem.md",
        "Simulation Recorder" => "man/simulation_recorder.md",
        "API" => Any["PowerSimulations" => "api/PowerSimulations.md"],
    ],
)

deploydocs(
    repo = "github.com/NREL-SIIP/PowerSimulations.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "master",
    devurl = "dev",
    versions = ["stable" => "v^", "v#.#"],
)
