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

        Fugl.run(entorno,title = "Asignación", 
                    window_width_px = 600, 
                    window_height_px = 300)
        return nothing
    end

    function entorno()
        button1_interaction = Ref(InteractionState())
        button2_interaction = Ref(InteractionState())
        button3_interaction = Ref(InteractionState())

        # Normal button style
        normal_style = ContainerStyle(
            background_color = Vec4f(0.2, 0.4, 0.8, 1.0),
            border_color = Vec4f(0.1, 0.3, 0.7, 1.0),
            border_width = 2.0f0,
            padding = 12.0f0,
            corner_radius = 6.0f0
        )

        # Hover style
        hover_style = ContainerStyle(
            background_color = Vec4f(0.3, 0.5, 0.9, 1.0),
            border_color = Vec4f(0.2, 0.4, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 12.0f0,
            corner_radius = 6.0f0
        )

        # Pressed style
        pressed_style = ContainerStyle(
            background_color = Vec4f(0.1, 0.2, 0.6, 1.0),
            border_color = Vec4f(0.05, 0.15, 0.5, 1.0),
            border_width = 2.0f0,
            padding = 12.0f0,
            corner_radius = 6.0f0
        )

        text_style = TextStyle(
            color = Vec4f(1.0, 1.0, 1.0, 1.0),
            size_points = 16
        )
        tfesc = TextField(EditorState("escuelas"),text_style=text_style)
        tfact = TextField(EditorState("actividades"),text_style=text_tyle)
        return Container(
            Column(
                Container(
                    Row(
                        tfesc,
                        TextButton(
                            "Seleccionar",
                            on_click = () -> tfesc.state = EditorState(pick_file()),
                            container_style = normal_style,
                            hover_style = hover_style,
                            pressed_style = pressed_style,
                            interaction_state = button_interaction[],
                            on_interaction_state_change = (new_state) -> button1_interaction[] = new_state
                        )
                    )
                ),
                Container(
                    Row(
                        tfact,
                        TextButton(
                            "Seleccionar",
                            on_click = () -> tfact.state = EditorState(pick_file()),
                            container_style = normal_style,
                            hover_style = hover_style,
                            pressed_style = pressed_style,
                            interaction_state = button_interaction[],
                            on_interaction_state_change = (new_state) -> button2_interaction[] = new_state
                        )
                    )
                ),
                Container(
                        TextButton(
                            "Seleccionar",
                            on_click = () -> nothing,
                            container_style = normal_style,
                            hover_style = hover_style,
                            pressed_style = pressed_style,
                            interaction_state = button_interaction[],
                            on_interaction_state_change = (new_state) -> button3_interaction[] = new_state
                        )
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
