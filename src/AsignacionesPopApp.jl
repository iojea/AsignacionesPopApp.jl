# In case you want to know, why the last line of the docstring below looks like it is:
# It will show the package (local) path when help on the package is invoked like     help?> AsignacionesPopApp
# but it will interpolate to an empty string on CI server,
# preventing appearing the server local path in the documentation built there.

"""
    Package AsignacionesPopApp

Aplicación para realizar la asignación de escuelas a actividades en las Semanas de las Ciencias.

"""

# $(isnothing(get(ENV, "CI", nothing)) ? ("\n" * "Package local path: " * pathof(AsignacionesPopApp)) : "")
module AsignacionesPopApp

    using DataFrames
    using Dates
    using Graphs
    using GraphsFlows
    using SimpleTraits
    using Printf
    using StatsBase: countmap
    using XLSX
    using SparseArrays
    using NativeFileDialog
    using Fugl


    include("data.jl")
    include("pre-filtrado.jl")
    include("inscripciones.jl")
    include("actividades.jl")
    include("grafos.jl")
    include("Edmonds_Karp_modificado.jl")
    include("devoluciones.jl")


    function (@main)(ARGS)
        tfesc = TextField(EditorState("escuelas"))
        tfact = TextField(EditorState("actividades"))

        return Container(
            Column(
                Container(
                    Row(
                        tfesc,
                        TextButton(
                            "Seleccionar", on_click = () -> abrir(tfesc)
                        )
                    )
                ),
                Container(
                    Row(
                        tfact,
                        TextButton(
                            "Seleccionar", on_click = () -> abrir(tfact)
                        )
                    )
                ),
                Container(
                    TextButton("Asignar", on_click = () -> asigna(tfesc, tfact))
                )
            )
        )
    end

    function abrir(tf)
        seleccion = pick_file()
        return tf.state = EditorState(seleccion)
    end
    function asigna(tfesc, tfact)
        return main(tfesc.state.text, tfact.state.text)
    end
end
