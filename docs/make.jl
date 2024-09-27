using Documenter
using PowerSystems
using PowerSimulations
using DataStructures

pages = OrderedDict(
    "Welcome Page" => "index.md",
    "Quick Start Guide" => "quick_start_guide.md",
    "Tutorials" => Any[
        "Single-step Problem" => "tutorials/decision_problem.md",
        "Multi-stage Production Cost Simulation" => "tutorials/pcm_simulation.md",
    ],
    "Modeler Guide" => Any[
        "modeler_guide/definitions.md",
        "modeler_guide/psi_structure.md",
        "modeler_guide/problem_templates.md",
        "modeler_guide/running_a_simulation.md",
        "modeler_guide/read_results.md",
        "modeler_guide/simulation_recorder.md",
        "modeler_guide/logging.md",
        "modeler_guide/debugging_infeasible_models.md",
        "modeler_guide/parallel_simulations.md",
        "modeler_guide/modeling_faq.md",
    ],
    "Model Developer Guide" => Any[
        "Operation Problem Structure" => "model_developer_guide/structure_of_operation_problem.md"
        "Troubleshooting" => "model_developer_guide/troubleshooting.md"
    ],
    "Code Base Developer Guide" => Any[
        "Developer Guide" => "code_base_developer_guide/developer.md",
        "Troubleshooting" => "code_base_developer_guide/troubleshooting.md",
        "Internals" => "code_base_developer_guide/internal.md",
    ],
    "Formulation Library" => Any[
        "Introduction" => "formulation_library/Introduction.md",
        "General" => "formulation_library/General.md",
        "Network" => "formulation_library/Network.md",
        "Thermal Generation" => "formulation_library/ThermalGen.md",
        "Renewable Generation" => "formulation_library/RenewableGen.md",
        "Load" => "formulation_library/Load.md",
        "Branch" => "formulation_library/Branch.md",
        "Services" => "formulation_library/Service.md",
        "Feedforwards" => "formulation_library/Feedforward.md",
        "Piecewise Linear Cost" => "formulation_library/Piecewise.md",
    ],
    "API Reference" => "api/PowerSimulations.md",
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
