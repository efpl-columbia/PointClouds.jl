import Documenter, PointClouds
(@isdefined Revise) && Revise.revise() # allow hot-reloading of docstrings

Documenter.DocMeta.setdocmeta!(PointClouds, :DocTestSetup, :(using PointClouds); recursive = true, warn = false)

Documenter.makedocs(
  sitename = "PointClouds.jl",
  repo = Documenter.Remotes.GitHub("efpl-columbia", "PointClouds.jl"),
  root = @__DIR__,
  pages = [
    "Overview" => "index.md",
    "tutorial.md",
    "input-output.md",
    "point-processing.md",
    "data-sources.md",
  ],
  modules = [PointClouds],
  checkdocs = :exports,
  linkcheck = true,
  format = Documenter.HTML(
    edit_link = nothing,
    prettyurls = get(ENV, "PRETTY_URLS", "") == "true",
  ),
)
