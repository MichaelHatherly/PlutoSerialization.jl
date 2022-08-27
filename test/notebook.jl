### A Pluto.jl notebook ###
# v0.19.11

using Markdown
using InteractiveUtils

# ╔═╡ 775d21d8-2609-11ec-16c3-f9468cf21068
if isdefined(@__MODULE__, :PlutoRunner)
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.develop(; url = dirname(@__DIR__))
	Pkg.add("PlutoTest")
	Pkg.add("Revise")
	using Revise
	using PlutoSerialization
	using PlutoTest
end

# ╔═╡ 4df95dc3-6106-4150-a1c6-2735d1d38106
module M

struct T
	x
end

end

# ╔═╡ e55bcebd-6efa-4c34-8019-b51c2bc20302
# serialize("M.T.jls", M.T([]))

# ╔═╡ 264a1a7b-1296-4eb9-9fee-38f7ec383287
@test deserialize("M.T.jls") isa M.T

# ╔═╡ 63db7529-7c44-4f75-a0fb-acb6753177d9
@test deserialize("M.T.jls").x isa Vector{Any}

# ╔═╡ 07a5518e-235e-4cdc-a7cb-cfb402837a73
func = x -> x + 1

# ╔═╡ 12442b83-5459-4f54-9ee3-9a2e87665bd3
# serialize("func.jls", M.T(func))

# ╔═╡ 1e2eba1f-b5fc-4f9b-9cc7-2088965373b9
@test deserialize("func.jls") isa M.T

# ╔═╡ fca9ab30-0819-47d4-a74d-72ac6bc2b58b
@test deserialize("func.jls").x isa Function

# ╔═╡ 0af7c4d0-08e8-421e-b158-e98190cefcdf
@test deserialize("func.jls").x(1) == 2

# ╔═╡ 4a64a0e8-6254-44fa-a50d-0976e1d8e8e9
function closure(x)
	function (y)
		x + y
	end
end

# ╔═╡ dfd9093d-5e7e-4db1-9d9e-dc1880105510
# serialize("closure.jls", M.T(closure(big"1")))

# ╔═╡ 062caef8-9831-4b8e-b05b-1eb7162bd38c
@test deserialize("closure.jls") isa M.T

# ╔═╡ a9ace2cc-8814-4341-abc4-5c3be976b34f
@test deserialize("closure.jls").x isa Function

# ╔═╡ 9fffa093-ed3a-4647-986f-addb484b1fb8
@test deserialize("closure.jls").x(big"1") isa BigInt

# ╔═╡ 89e7273f-8d43-46b8-a44e-281dd45698f7
@test deserialize("closure.jls").x(1) == big"2"

# ╔═╡ Cell order:
# ╠═775d21d8-2609-11ec-16c3-f9468cf21068
# ╠═4df95dc3-6106-4150-a1c6-2735d1d38106
# ╠═e55bcebd-6efa-4c34-8019-b51c2bc20302
# ╠═264a1a7b-1296-4eb9-9fee-38f7ec383287
# ╠═63db7529-7c44-4f75-a0fb-acb6753177d9
# ╠═07a5518e-235e-4cdc-a7cb-cfb402837a73
# ╠═12442b83-5459-4f54-9ee3-9a2e87665bd3
# ╠═1e2eba1f-b5fc-4f9b-9cc7-2088965373b9
# ╠═fca9ab30-0819-47d4-a74d-72ac6bc2b58b
# ╠═0af7c4d0-08e8-421e-b158-e98190cefcdf
# ╠═4a64a0e8-6254-44fa-a50d-0976e1d8e8e9
# ╠═dfd9093d-5e7e-4db1-9d9e-dc1880105510
# ╠═062caef8-9831-4b8e-b05b-1eb7162bd38c
# ╠═a9ace2cc-8814-4341-abc4-5c3be976b34f
# ╠═9fffa093-ed3a-4647-986f-addb484b1fb8
# ╠═89e7273f-8d43-46b8-a44e-281dd45698f7
