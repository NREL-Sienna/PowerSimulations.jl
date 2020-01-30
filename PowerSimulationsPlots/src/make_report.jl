"""
    report(res::PSI.Results, out_path::String)

This function uses weave to either generate a LaTeX or HTML
file based on the report_design.jmd (julia markdown) file
that it reads. Out_path in the weave function dictates
where the created file gets exported.

# Arguments
- `results::PSI.Results`: The results to be plotted
- `out_path::String`: folder path to the location the report should be generated

# Example
```julia
results = solve_op_problem!(OpModel)
out_path = "/Users/downloads"
report(results, out_path)
```

# Accepted Key Words
- `doctype::String = "md2html"`: create an HTML, default is PDF via latex
- `backend::Plots.backend() = plotlyjs()`: sets the plots backend, default is gr()
- `jmd::String = "file_path"`: directs the function to the julia markdown report design, the default
is ".../pwd()/report_design/report_design.jmd". To change the report, use report_design.jmd as a template
and add additional markdowns to the report_design folder.
"""
function report(res::PSI.Results, out_path::String; kwargs...)

    doctype = get(kwargs, :doctype, "md2pdf")
    backend = get(kwargs, :backend, Plots.gr())
    default_string = joinpath(pwd(), "src/report_design/report_design.jmd")
    jmd = get(kwargs, :jmd, default_string)
    args = Dict("res" => res, "variables" => res.variables, "backend" => backend)
    Weave.weave(
        jmd,
        out_path = out_path,
        latex_cmd = "xelatex",
        doctype = doctype,
        args = args,
    )

end

"""
    report(res::PSI.Results, generators::Dict, out_path::String)

This function uses weave to either generate a LaTeX or HTML
file based on the report_design.jmd (julia markdown) file
that it reads. Out_path in the weave function dictates
where the created file gets exported.

# Arguments
- `results::PSI.Results`: The results to be plotted
- `generators::Dict`: the dictionary of generators and their fuel type made by make_fuel_dictionary
- `out_path::String`: folder path to the location the report should be generated

# Example
```julia
results = solve_op_problem!(OpModel)
generators = make_fuel_dictionary(PSY.system, results)
out_path = "/Users/downloads"
report(results, generators, out_path)
```

# Accepted Key Words
- `doctype::String = "md2html"`: create an HTML, default is PDF via latex
- `backend::Plots.backend() = plotlyjs()`: sets the plots backend, default is gr()
- `jmd::String = "file_path"`: directs the function to the julia markdown report design, the default
is ".../pwd()/report_design/report_design_fuel.jmd". To change the report, use report_design_fuel.jmd as a template
and add additional markdowns to the report_design folder.
"""

function report(res::PSI.Results, generators::Dict, out_path::String; kwargs...)

    doctype = get(kwargs, :doctype, "md2pdf")
    backend = get(kwargs, :backend, Plots.gr())
    default_string = joinpath(pwd(), "src/report_design/report_design_fuel.jmd")
    jmd = get(kwargs, :jmd, default_string)
    args = Dict(
        "res" => res,
        "variables" => res.variables,
        "gen" => generators,
        "backend" => backend,
    )
    Weave.weave(
        jmd,
        out_path = out_path,
        latex_cmd = "xelatex",
        doctype = doctype,
        args = args,
    )

end

"""
    report(res::PSI.Results, system::PSY.System, out_path::String)

This function uses weave to either generate a LaTeX or HTML
file based on the report_design.jmd (julia markdown) file
that it reads. Out_path in the weave function dictates
where the created file gets exported.

# Arguments
- `results::PSI.Results`: The results to be plotted
- `system::PSY.System`: the system used to create the results for sorting by fuel type
- `out_path::String`: folder path to the location the report should be generated

# Example
```julia
results = solve_op_problem!(OpModel)
out_path = "/Users/downloads"
report(results, PSY.system, out_path)
```

# Accepted Key Words
- `doctype::String = "md2html"`: create an HTML, default is PDF via latex
- `backend::Plots.backend() = plotlyjs()`: sets the plots backend, default is gr()
- `jmd::String = "file_path"`: directs the function to the julia markdown report design, the default
is ".../pwd()/report_design/report_design_fuel.jmd". To change the report, use report_design_fuel.jmd as a template
and add additional markdowns to the report_design folder.
"""

function report(res::PSI.Results, system::PSY.System, out_path::String; kwargs...)

    doctype = get(kwargs, :doctype, "md2pdf")
    backend = get(kwargs, :backend, gr())
    default_string = joinpath(pwd(), "src/report_design/report_design_fuel.jmd")
    jmd = get(kwargs, :jmd, default_string)
    args = Dict(
        "res" => res,
        "variables" => res.variables,
        "gen" => system,
        "backend" => backend,
    )
    Weave.weave(
        jmd,
        out_path = out_path,
        latex_cmd = "xelatex",
        doctype = doctype,
        args = args,
    )

end
