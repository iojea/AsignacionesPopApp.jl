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

        button1_interaction = Ref(InteractionState())
        button2_interaction = Ref(InteractionState())

        # Normal button style
        normal_style = ContainerStyle(
            background_color = Vec4f(0.9, 0.9, 0.9, 1.0),
            border_color = Vec4f(0.8, 0.8, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 12.0f0,
            corner_radius = 6.0f0
        )

        # Hover style
        hover_style = ContainerStyle(
            background_color = Vec4f(0.7, 0.7, 0.7, 1.0),
            border_color = Vec4f(0.8, 0.8, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 12.0f0,
            corner_radius = 6.0f0
        )

        # Pressed style
        pressed_style = ContainerStyle(
            background_color = Vec4f(0.85, 0.85, 0.95, 1.0),
            border_color = Vec4f(0.8, 0.8, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 12.0f0,
            corner_radius = 6.0f0
        )
        header_style = TextStyle(
            color=Vec4f(0.1, 0.7, 0.7, 1.0),
            size_px= 24,
        )
        # text_style = TextStyle(
        #     color = Vec4f(1.0, 1.0, 1.0, 1.0),
        #     size_points = 16
        # )
        esc = Ref("")
        act = Ref("")
        function entorno()
            apppath = Base.pathof(AsignacionesPopApp)
            im      = joinpath([joinpath(splitpath(apppath)[1:end-1]),"assets/folder.png"])
            Container(Column(
                Container(
                    Column(
                        Fugl.Text("Escuelas",horizontal_align=:left,style=header_style),
                        IntrinsicRow(
                            FixedSize(IconButton(im,
                                on_click = () -> esc[] = NativeFileDialog.pick_file(),
                                container_style = normal_style,
                                hover_style = hover_style,
                                pressed_style = pressed_style,
                                interaction_state = button1_interaction[],
                                on_interaction_state_change = (new_state) -> button1_interaction[] = new_state
                                ),100,100),
                            Fugl.Text(esc[],vertical_align=:middle)
                            )
                        )
                    ),
                Container(
                    Column(
                        Fugl.Text("Actividades",horizontal_align=:left,style=header_style),
                        IntrinsicRow(
                            FixedSize(IconButton(im,
                                on_click = () -> act[] = NativeFileDialog.pick_file(),
                                container_style = normal_style,
                                hover_style = hover_style,
                                pressed_style = pressed_style,
                                interaction_state = button2_interaction[],
                                on_interaction_state_change = (new_state) -> button2_interaction[] = new_state
                                ),100,100),
                            Fugl.Text(act[],vertical_align=:middle)
                            )
                        )
                    ),
                ))
        end
        Fugl.run(entorno,title = "Asignación", 
                    window_width_px = 400, 
                    window_height_px = 200)
        return nothing
    end

    function asigna(tfesc, tfact)
        return main(tfesc.state.text, tfact.state.text)
    end
end
