using Documenter
using PowerSystems
using PowerSimulations
using Literate
using DataStructures

pages = OrderedDict(
        "Welcome Page" => "index.md",
        "Quick Start Guide" => "quick_start_guide.md",
        "Tutorials" =>  "tutorials/intro_page.md",
        "Modeler Guide" =>
            Any[
            #"modeler_guide/type_structure.md",
            #"modeler_guide/system.md",
            #"modeler_guide/time_series.md",
            #"modeler_guide/enumerated_types.md",
            #"modeler_guide/example_dynamic_data.md",
            "modeler_guide/definitions.md",
            "modeler_guide/simulation_recorder.md",
            "modeler_guide/Logging.md"
            ],
        "Model Developer Guide" =>
            Any[
                "Adding Formulation" => "model_developer_guide/adding_device_formulation.md"
                "Adding Problems" => "model_developer_guide/adding_new_problem_model.md"
                "Troubleshooting" => "model_developer_guide/troubleshooting.md"
            ],
        "Code Base Developer Guide" =>
            Any[
                "Developer Guide" => "code_base_developer_guide/developer.md",
                "Troubleshooting" => "code_base_developer_guide/troubleshooting.md"
            ],
        "Formulation Library" => Any[
            "Thermal Generation" => "formulation_library/ThermalGen.md",
            "Hydro Generation" => "formulation_library/HydroGen.md",
            "Storage" => "formulation_library/Storage.md",
            "Network" => "formulation_library/Network.md"
        ],
        "Public API Reference" => "api/public.md",
        "Internal API Reference" => "api/internal.md"
)

deploydocs(
    repo="github.com/NREL-SIIP/PowerSimulations.jl.git",
    target="build",
    branch="gh-pages",
    devbranch="master",
    devurl="dev",
    push_preview=true,
    versions=["stable" => "v^", "v#.#"],
)
