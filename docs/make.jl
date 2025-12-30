using Documenter
using PowerSystems
using PowerSimulations
using DataStructures
using DocumenterInterLinks
using Literate

links = InterLinks(
    "Julia" => "https://docs.julialang.org/en/v1/",
    "InfrastructureSystems" => "https://nrel-sienna.github.io/InfrastructureSystems.jl/stable/",
    "PowerSystems" => "https://nrel-sienna.github.io/PowerSystems.jl/stable/",
    "PowerSimulations" => "https://nrel-sienna.github.io/PowerSimulations.jl/stable/",
    "StorageSystemsSimulations" => "https://nrel-sienna.github.io/StorageSystemsSimulations.jl/stable/",
    "HydroPowerSimulations" => "https://nrel-sienna.github.io/HydroPowerSimulations.jl/dev/",
)

# Function to clean up old generated files
function clean_old_generated_files(dir::String; remove_all_md::Bool=false)
    if !isdir(dir)
        @warn "Directory does not exist: $dir"
        return
    end
    if remove_all_md
        generated_files = filter(f -> endswith(f, ".md"), readdir(dir))
    else
        generated_files = filter(f -> startswith(f, "generated_") && endswith(f, ".md"), readdir(dir))
    end
    for file in generated_files
        rm(joinpath(dir, file), force=true)
        @info "Removed old generated file: $file"
    end
end

# Function to add download links to generated markdown
function add_download_links(content, jl_file, ipynb_file)
    download_section = """

*To follow along, you can download this tutorial as a [Julia script (.jl)](../$(jl_file)) or [Jupyter notebook (.ipynb)]($(ipynb_file)).*

"""
    m = match(r"^(#+ .+)$"m, content)
    if m !== nothing
        heading = m.match
        content = replace(content, r"^(#+ .+)$"m => heading * download_section, count=1)
    end
    return content
end

# Process tutorials with Literate
tutorial_files = filter(x -> occursin(".jl", x), readdir("docs/src/tutorials"))
if !isempty(tutorial_files)
    tutorial_outputdir = joinpath(pwd(), "docs", "src", "tutorials", "generated")
    clean_old_generated_files(tutorial_outputdir; remove_all_md=true)
    mkpath(tutorial_outputdir)
    
    for file in tutorial_files
        @show file
        infile_path = joinpath(pwd(), "docs", "src", "tutorials", file)
        execute = occursin("EXECUTE = TRUE", uppercase(readline(infile_path))) ? true : false
        execute && include(infile_path)
        
        outputfile = replace("$file", ".jl" => "")
        
        # Generate markdown
        Literate.markdown(infile_path,
                          tutorial_outputdir;
                          name = outputfile,
                          credit = false,
                          flavor = Literate.DocumenterFlavor(),
                          documenter = true,
                          postprocess = (content -> add_download_links(content, file, string(outputfile, ".ipynb"))),
                          execute = execute)
        
        # Generate notebook
        Literate.notebook(infile_path,
                          tutorial_outputdir;
                          name = outputfile,
                          credit = false,
                          execute = false)
    end
end

pages = OrderedDict(
    "Welcome Page" => "index.md",
    "Tutorials" => Any[
        "Single-step Problem" => "tutorials/generated/decision_problem.md",
        "Multi-stage Production Cost Simulation" => "tutorials/generated/pcm_simulation.md",
    ],
    "How to..." => Any[
        "...register a variable in a custom operation model" => "how_to/register_variable.md",
        "...create a problem template" => "how_to/problem_templates.md",
        "...read the simulation results" => "how_to/read_results.md",
        "...debug an infeasible model" => "how_to/debugging_infeasible_models.md",
        "...configure logging" => "how_to/logging.md",
        "...inspect simulation events using the recorder" => "how_to/simulation_recorder.md",
        "...run a parallel simulation" => "how_to/parallel_simulations.md",
    ],
    "Explanation" => Any[
        "explanation/psi_structure.md",
        "explanation/feedforward.md",
        "explanation/chronologies.md",
        "explanation/sequencing.md",
    ],
    "Reference" => Any[
        "Glossary and Acronyms" => "api/glossary.md",
        "Public API" => "api/PowerSimulations.md",
        "Developers" => ["Developer Guidelines" => "api/developer.md",
            "Internals" => "api/internal.md"],
    ],
    "Archived Old Docs Content" => "archive_old_docs_content.md",
    "Formulation Library" => Any[
        "Introduction" => "formulation_library/Introduction.md",
        "General" => "formulation_library/General.md",
        "Network" => "formulation_library/Network.md",
        "Thermal Generation" => "formulation_library/ThermalGen.md",
        "Renewable Generation" => "formulation_library/RenewableGen.md",
        "Load" => "formulation_library/Load.md",
        "Branch" => "formulation_library/Branch.md",
        "Source" => "formulation_library/Source.md",
        "Services" => "formulation_library/Service.md",
        "Feedforwards" => "formulation_library/Feedforward.md",
        "Piecewise Linear Cost" => "formulation_library/Piecewise.md",
    ],
)

makedocs(;
    modules = [PowerSimulations],
    format = Documenter.HTML(;
        prettyurls = haskey(ENV, "GITHUB_ACTIONS"),
        size_threshold = nothing),
    sitename = "PowerSimulations.jl",
    authors = "Jose Daniel Lara, Daniel Thom, Kate Doubleday, Rodrigo Henriquez-Auba, and Clayton Barrows",
    pages = Any[p for p in pages],
)

deploydocs(;
    repo = "github.com/NREL-Sienna/PowerSimulations.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "main",
    devurl = "dev",
    push_preview = true,
    versions = ["stable" => "v^", "v#.#"],
)
