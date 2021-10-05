using Pluto
using Test
using Markdown
using InteractiveUtils
using PlutoSerialization

@testset "PlutoSerialization.jl" begin
    include("notebook.jl")
    s = Pluto.ServerSession()
    nb = Pluto.SessionActions.open(s, joinpath(@__DIR__, "notebook.jl"); run_async = false)
end

