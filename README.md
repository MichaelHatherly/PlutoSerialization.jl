# PlutoSerialization

This package provides `serialize` and `deserialize` functions which are
compatible with the standard library `Serialization` module's function, but are
able to handle serializing/deserializing data from/to `Pluto` notebooks.

## Details

Standard `Serialization` does not work inside `Pluto` notebooks since
evaluation of cells will increment the current "workspace" `Module` into which
definitions are evaluated. This is done to allow for re-definition of constants
such as type definitions, but means that `Serialization.serialize` will save
`Module` references that may not exist when we `deserialize` the file in a new
notebook session since the workspace number will not likely be the same.

This package implements a custom `Serialization.AbstractSerializer` that
searches all defined workspaces for valid definitions during `deserialize`
allowing it to not have to rely on fixed `Module` references. Aside from the
changes required for searching workspaces it should replicate the behaviour of
`Serialization`.

