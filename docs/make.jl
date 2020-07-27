using Documenter
using PowerSystems
using PowerSimulations
using Literate
using PowerGraphics
const PG = PowerGraphics

folders = Dict(
    #  "Operations" => readdir("docs/src/Operations"),
    #  "Simulations" => readdir("docs/src/Simulations"),
    "PowerGraphics" => readdir("docs/src/PowerGraphics"),
)

for (name, folder) in folders
    for file in folder
        outputdir = joinpath(pwd(), "docs/src/howto")
        inputfile = joinpath(pwd(), "docs/src/$name/$file")
        Literate.markdown(inputfile, outputdir)
    end
end
if isfile("docs/src/howto/.DS_Store.md")
    rm("docs/src/howto/.DS_Store.md")
end

makedocs(
    sitename = "PowerSimulations.jl",
    format = Documenter.HTML(
        mathengine = Documenter.MathJax(),
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    modules = [PowerSimulations],
    strict = true,
    authors = "Jose Daniel Lara, Clayton Barrows and Dheepak Krishnamurthy",
    pages = Any[
        "Introduction" => "index.md",
        #"Quick Start Guide" => "qs_guide.md",
        "Logging" => "man/logging.md",
        "Operation Model" => "man/op_problem.md",
        "How To" => Any[
            "Set Up Plots" => "howto/3.0_set_up_plots.md",
            "Make Stack Plots" => "howto/3.1_make_stack_plots.md",
            "Make Bar Plots" => "howto/3.2_make_bar_plots.md",
            "Make Fuel Plots" => "howto/3.3_make_fuel_plots.md",
            "Make Forecast Plots" => "howto/3.4_make_forecast_plots.md",
            "Plot Fewer Variables" => "howto/3.5_plot_fewer_variables.md",
            "Plot Multiple Results" => "howto/3.6_plot_multiple_results.md",
        ],
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
