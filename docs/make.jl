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
        "Operation Model" => "man/op_problem.md",
        "Simulation Recorder" => "man/simulation_recorder.md",
        "API" => Any["PowerSimulations" => "api/PowerSimulations.md"],
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#

deploydocs(
    repo = "github.com/NREL-SIIP/PowerSimulations.jl.git",
    branch = "gh-pages",
    target = "build",
    #deps = Deps.pip("pygments", "mkdocs", "python-markdown-math"),
    make = nothing,
)
