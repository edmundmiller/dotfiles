atreplinit() do repl
    try
        @eval using OhMyREPL
    catch e
        @warn "error while importing OhMyREPL" e
    end
end

try
    using Revise
catch e
    @warn "Error initializing Revise" exception=(e, catch_backtrace())
end

# Auto start the local project
# https://bkamins.github.io/julialang/2020/05/10/julia-project-environments.html
using Pkg
if isfile("Project.toml") && isfile("Manifest.toml")
    Pkg.activate(".")
end
