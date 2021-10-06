using Pluto
using Test
using Markdown
using InteractiveUtils
using PlutoSerialization

module workspace100
module PlutoRunner
end
end
module var"workspace#200"
module PlutoRunner
end
end

@testset "PlutoSerialization.jl" begin
    @testset "workspace parsing" begin
        @test PlutoSerialization.ws_number(Module(:workspace)) === nothing
        @test PlutoSerialization.ws_number(Module(:workspace1)) == 1
        @test PlutoSerialization.ws_number(Module(Symbol("workspace#10"))) == 10
        @test PlutoSerialization.get_ws() == Dict(100 => workspace100, 200 => var"workspace#200")
    end

    @testset "roundtrip outside pluto" begin
        let buffer = IOBuffer()
            serialize(buffer, x -> x + 1)
            @test deserialize(seekstart(buffer))(1) == 2
        end
    end

    @testset "notebook" begin
        include("notebook.jl")
        s = Pluto.ServerSession()
        nb = Pluto.SessionActions.open(s, joinpath(@__DIR__, "notebook.jl"); run_async = false)
    end
end

