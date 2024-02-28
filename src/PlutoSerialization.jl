"""
A package to allow serializing and deserializing data from a Pluto notebook.
Provides `serialize` and `deserialize` functions which follow the same
interface as those provided by the `Serialization`, but do not extend it.
Importing both will result in name conflicts, use one or the other, not both.
"""
module PlutoSerialization

# Imports:

import Serialization


# Exports:

export deserialize
export serialize


# Public interface:

"""
    serialize(filename::AbstractString, object)
    serialize(io::IO, object)

Save the given `object` to `filename` or `io` using Julia's serialization, but
additionally handle Pluto's workspace modules such that the saved data can be
`deserialized` in a new session.
"""
function serialize end

function serialize(io::IO, @nospecialize(object))
    ps = PlutoSerializer(io)
    Serialization.writeheader(ps)
    Serialization.serialize(ps, object)
end
serialize(fn::AbstractString, @nospecialize(object)) = open(io -> serialize(io, object), fn, "w")

"""
    deserialize(filename::AbstractString)
    deserialize(io::IO)

Deserialize `filename` or `io` into a Julia object using Julia's serialization,
but correctly handle Pluto's workspace modules.
"""
function deserialize end

deserialize(io::IO) = Serialization.deserialize(PlutoSerializer(io))
deserialize(fn::AbstractString) = open(deserialize, fn)

# A mock top-level module to mark module references serialized in notebooks.
baremodule PlutoWorkspaces end
_parentmodule(m::Module) = m === PlutoWorkspaces ? PlutoWorkspaces : parentmodule(m)
_root_module_key(m::Module) = m === PlutoWorkspaces ? Base.PkgId("PlutoWorkspaces") : Base.root_module_key(m)
_root_module(pkgid::Base.PkgId) = Base.PkgId("PlutoWorkspaces") === pkgid ? PlutoWorkspaces : Base.root_module(pkgid)

# Implementation:

# Serialization and deserialization code for handling pluto notebook
# environments correctly. Notebooks incrementally add `workspaceN` modules when
# they re-evaluate cells, but when restarting a notebook `N` begins again from
# `1` rather than preserving the previous state (nothing wrong with this), but
# it means that using the default `serialize` and `deserialize` will likely
# store and load `workspaceN` modules that probably don't exist.
#
# To handle this, we implement an `AbstractSerializer` that checks through all
# available workspaces when deserializing objects to find the most recent
# reference to the object name, rather than expecting the specific named
# workspace to exist.

"""
Find all Pluto workspace modules and return an `id => mod` mapping for each.
"""
function get_ws()
    dict = Dict{Int,Module}()
    for name in names(Main)
        id = ws_number(name)
        isnothing(id) && continue
        if isdefined(Main, name)
            obj = getfield(Main, name)
            if isa(obj, Module) && isdefined(obj, :PlutoRunner)
                dict[id] = obj
            end
        end
    end
    return dict
end

"""
The `Int` representing a Pluto workspace, or `nothing` if not valid.
"""
function ws_number(name::Symbol)
    str = String(name)
    m = match(r"^workspace[#]?(\d+)$", str)
    return isnothing(m) ? nothing : tryparse(Int, m[1])
end
ws_number(m::Module) = ws_number(nameof(m))

"""
Check through workspace modules from most recent and find the first module in
which the `name` is defined, that's *probably* the right one... otherwise just
give up and return the `default` module instead.
"""
function maybe_defined_in_workspace(workspaces::Dict, name::Symbol, default::Module)
    for id in length(workspaces):-1:1
        if haskey(workspaces, id)
            mod = workspaces[id]
            isdefined(mod, name) && return mod
        end
    end
    return isdefined(Main, name) ? Main : default
end


# Serialization implementation:
#
# Adapts some of the methods of `AbstractSerializer` to handle searching
# through all available workspace modules to find valid deserialized objects,
# but for the most part simply reuses the default `Serialization` methods.

mutable struct PlutoSerializer{I<:IO} <: Serialization.AbstractSerializer
    io::I
    counter::Int
    table::IdDict{Any,Any}
    pending_refs::Vector{Int}
    known_object_data::Dict{UInt64,Any}
    version::Int
    workspaces::Dict{Int,Module}
    PlutoSerializer{I}(io::I) where I<:IO = new(io, 0, IdDict(), Int[], Dict{UInt64,Any}(), Serialization.ser_version, get_ws())
end

PlutoSerializer(io::IO) = PlutoSerializer{typeof(io)}(io)

function Serialization.serialize_mod_names(s::PlutoSerializer, m::Module)
    # Swap out the workspace module for a custom toplevel one that we control
    # to "mark" it as a workspace.
    m = haskey(s.workspaces, ws_number(m)) ? PlutoWorkspaces : m
    p = _parentmodule(m)
    if p === m || m === Base
        key = _root_module_key(m)
        Serialization.serialize(s, key.uuid === nothing ? nothing : key.uuid.value)
        Serialization.serialize(s, Symbol(key.name))
    else
        Serialization.serialize_mod_names(s, p)
        Serialization.serialize(s, nameof(m))
    end
end

function Serialization.deserialize_module(s::PlutoSerializer)
    mkey = Serialization.deserialize(s)
    if isa(mkey, Tuple)
        # old version, TODO: remove
        if mkey === ()
            return Main
        end
        m = _root_module(mkey[1])
        for i = 2:length(mkey)
            m = getfield(m, mkey[i])::Module
        end
    else
        name = String(Serialization.deserialize(s)::Symbol)
        pkg = (mkey === nothing) ? Base.PkgId(name) : Base.PkgId(Base.UUID(mkey), name)
        m = _root_module(pkg)
        mname = Serialization.deserialize(s)
        while mname !== ()
            m = maybe_defined_in_workspace(s.workspaces, mname, m)
            m = getfield(m, mname)::Module
            mname = Serialization.deserialize(s)
        end
    end
    return m === PlutoWorkspaces ? get(s.workspaces, length(s.workspaces), Main) : m
end

function Serialization.deserialize_datatype(s::PlutoSerializer, full::Bool)
    slot = s.counter
    s.counter += 1
    if full
        tname = Serialization.deserialize(s)::Core.TypeName
        ty = tname.wrapper
    else
        name = Serialization.deserialize(s)::Symbol
        mod = Serialization.deserialize(s)::Module
        mod = maybe_defined_in_workspace(s.workspaces, name, mod)
        ty = getfield(mod, name)
    end
    if isa(ty,DataType) && isempty(ty.parameters)
        t = ty
    else
        np = Int(read(s.io, Int32)::Int32)
        if np == 0
            t = Base.unwrap_unionall(ty)
        elseif ty === Tuple
            # note np==0 has its own tag
            if np == 1
                t = Tuple{Serialization.deserialize(s)}
            elseif np == 2
                t = Tuple{Serialization.deserialize(s), Serialization.deserialize(s)}
            elseif np == 3
                t = Tuple{Serialization.deserialize(s), Serialization.deserialize(s), Serialization.deserialize(s)}
            elseif np == 4
                t = Tuple{Serialization.deserialize(s), Serialization.deserialize(s), Serialization.deserialize(s), Serialization.deserialize(s)}
            else
                t = Tuple{Any[Serialization.deserialize(s) for _ = 1:np]...}
            end
        else
            t = ty
            for _ = 1:np
                t = t{Serialization.deserialize(s)}
            end
        end
    end
    s.table[slot] = t
    return t
end

# Might need to adjust, but the idea here is that *all* the required
# definitions should already exist within the notebook, we shouldn't be
# deserializing anything that doesn't already have the whole type available.
# May need to re-evaluate this choice.
Serialization.should_send_whole_type(s::PlutoSerializer, t::DataType) = false

end

