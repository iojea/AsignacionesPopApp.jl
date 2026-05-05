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

    include("data.jl")
    include("pre-filtrado.jl")
    include("inscripciones.jl")
    include("actividades.jl")
    include("grafos.jl")
    include("Edmonds_Karp_modificado.jl")
    include("devoluciones.jl")


    function (@main)(ARGS)
        println("Seleccione el archivo de escuelas.")
        escuelas = NativeFileDialog.file_pick()
        println("Archivo selecionado: ", escuelas)
        println("Seleccione el archivo de actividades.")
        actividades = file_pick()
        println("Archivo selecionado: ", actividades)
        return main(escuelas, actividades)
    end

end
