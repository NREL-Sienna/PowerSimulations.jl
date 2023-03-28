using Documenter
using PowerSystems
using PowerSimulations
using DataStructures

pages = OrderedDict(
    "Welcome Page" => "index.md",
    "Quick Start Guide" => "quick_start_guide.md",
    "Modeler Guide" => Any[
        "modeler_guide/definitions.md",
        "modeler_guide/psi_structure.md",
        "modeler_guide/problem_templates.md",
        "modeler_guide/running_a_simulation.md",
        "modeler_guide/simulation_recorder.md",
        "modeler_guide/logging.md",
        "modeler_guide/tips_and_tricks.md",
        "modeler_guide/debugging_infeasible_models.md",
        "modeler_guide/parallel_simulations.md",
        "modeler_guide/modeling_faq.md",
    ],
    "Model Developer Guide" => Any[
        "Adding Formulations" => "model_developer_guide/adding_new_device_formulation.md"
        "Adding Problems" => "model_developer_guide/adding_new_problem_model.md"
        "Troubleshooting" => "model_developer_guide/troubleshooting.md"
    ],
    "Code Base Developer Guide" => Any[
        "Developer Guide" => "code_base_developer_guide/developer.md",
        "Troubleshooting" => "code_base_developer_guide/troubleshooting.md",
    ],
    "Formulation Library" => Any[
        "General" => "formulation_library/General.md",
        "Thermal Generation" => "formulation_library/ThermalGen.md",
        "Hydro Generation" => "formulation_library/HydroGen.md",
        "Renewable Generation" => "formulation_library/RenewableGen.md",
        "Storage" => "formulation_library/Storage.md",
        "Load" => "formulation_library/Load.md",
        "Network" => "formulation_library/Network.md",
        "Branch" => "formulation_library/Branch.md",
    ],
    "API Reference" => "api/PowerSimulations.md",
)

makedocs(;
    modules = [PowerSimulations],
    format = Documenter.HTML(; prettyurls = haskey(ENV, "GITHUB_ACTIONS")),
    sitename = "PowerSimulations.jl",
    authors = "Jose Daniel Lara, Daniel Thom and Clayton Barrows",
    pages = Any[p for p in pages],
)

deploydocs(;
    repo = "github.com/NREL-SIIP/PowerSimulations.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "master",
    devurl = "dev",
    push_preview = true,
    versions = ["stable" => "v^", "v#.#"],
)
