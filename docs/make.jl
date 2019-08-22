import Pkg;
Pkg.add("Documenter")
using Documenter
using PowerSimulations

makedocs(
    sitename = "PowerSimulations",
    format = Documenter.HTML(),
    modules = [PowerSimulations]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#

deploydocs(
    repo = "github.com/NREL/PowerSimulations.jl.git",
    branch = "gh-pages",
    target = "build",
    deps = Deps.pip("pygments", "mkdocs", "python-markdown-math"),
    make = nothing,
)
