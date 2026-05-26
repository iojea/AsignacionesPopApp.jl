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
    include("corroboraciones.jl")
    include("pre-filtrado.jl")
    include("inscripciones.jl")
    include("actividades.jl")
    include("grafos.jl")
    include("Edmonds_Karp_modificado.jl")
    include("devoluciones.jl")


    function (@main)(ARGS)

        button1_interaction = Ref(InteractionState())
        button2_interaction = Ref(InteractionState())
        button3_interaction = Ref(InteractionState())
        button4_interaction = Ref(InteractionState())

        ## Estilos
        # Estilos de botón
        normal_style = ContainerStyle(
            background_color = Vec4f(0.9, 0.9, 0.9, 1.0),
            border_color = Vec4f(0.8, 0.8, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 0.5f0,
            corner_radius = 6.0f0
        )

        hover_style = ContainerStyle(
            background_color = Vec4f(0.7, 0.7, 0.7, 1.0),
            border_color = Vec4f(0.8, 0.8, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 0.5f0,
            corner_radius = 6.0f0
        )

        pressed_style = ContainerStyle(
            background_color = Vec4f(0.85, 0.85, 0.95, 1.0),
            border_color = Vec4f(0.8, 0.8, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 0.5f0,
            corner_radius = 6.0f0
        )

        # Estilos de texto
        header_style = TextStyle(
            color = Vec4f(0.1, 0.7, 0.7, 1.0),
            size_px = 32
        )
        file_style = TextStyle(
            color = Vec4f(0.4, 0.4, 0.4, 1.0),
            size_px = 24
        )
        err_style = TextStyle(
            color = Vec4f(1.0, 0.0, 0.0, 1.0),
            size_px = 24
        )
        ok_style = TextStyle(
            color = Vec4f(0.0, 1.0, 0.0, 1.0),
            size_px = 24
        )

        ### Textos
        esc = Ref("")
        act = Ref("")
        pre = Ref("")
        outpre = Ref("")
        errpre = Ref("")
        okpre = Ref("")
        destino = Ref("")
        outas = Ref("")
        outas2 = Ref("")
        erras = Ref("")
        okas = Ref("")


        ### Preprocesado
        function prepro()
            try
                df, repetidos_a_chequear = primer_filtrado(esc[], act[])
                okpre[] = "✔"
                outpre[] = "Preprocesado con éxito. Guarde los resultados."
                sleep(1.0)
                pre[] = NativeFileDialog.save_file()
                XLSX.writetable(
                    pre[],
                    "Filtrados" => Tables.columntable(df),
                    "Repetidos" => Tables.columntable(repetidos_a_chequear);
                    overwrite = true
                )
            catch e
                errpre[] = "×"
                outpre[] = "Ocurrió un error. Revise el mensaje en la terminal."
                sleep(1.0)
                println(e)
            end
            return nothing
        end

        ### Asignación
        function asignar()
            try
                asignacion, residuos = main(pre[], act[])
                okas[] = "✔"
                outas[] = "Asignación existosa. Seleccione la carpeta para guardar los resultados."
                sleep(1.0)
                destino[] = pick_folder()
                outas2[] = "Asignación guardada en " * destino[]
            catch e
                erras[] = "×"
                outas[] = "Ocurrió un error. Revise el mensaje en la terminal."
                sleep(1.0)
                println(e)
            end
            return nothing
        end
        ######################################## APP #########################################
        function entorno()
            apppath = Base.pathof(AsignacionesPopApp)
            im = joinpath([joinpath(splitpath(apppath)[1:(end - 1)]), "assets/folder.png"])
            return Container(
                IntrinsicColumn(
                    FixedSize(Container(
                        Column(
                            Fugl.Text("Escuelas", horizontal_align = :left, style = header_style),
                            IntrinsicRow(
                                FixedSize(
                                    IconButton(
                                        im,
                                        on_click = () -> esc[] = NativeFileDialog.pick_file(),
                                        container_style = normal_style,
                                        hover_style = hover_style,
                                        pressed_style = pressed_style,
                                        interaction_state = button1_interaction[],
                                        on_interaction_state_change = (new_state) -> button1_interaction[] = new_state
                                    ), 100, 100
                                ),
                                Fugl.Text(esc[], vertical_align = :middle, style = file_style)
                            )
                        )
                    ),1200,200),
                    FixedSize(Container(
                        Column(
                            Fugl.Text("Actividades", horizontal_align = :left, style = header_style),
                            IntrinsicRow(
                                FixedSize(
                                    IconButton(
                                        im,
                                        on_click = () -> act[] = NativeFileDialog.pick_file(),
                                        container_style = normal_style,
                                        hover_style = hover_style,
                                        pressed_style = pressed_style,
                                        interaction_state = button2_interaction[],
                                        on_interaction_state_change = (new_state) -> button2_interaction[] = new_state
                                    ), 100, 100
                                ),
                                Fugl.Text(act[], vertical_align = :middle, style = file_style)
                            )
                        ),
                    ),1200,200),
                    HLine(style = SeparatorStyle(line_width = 2.0f0, color = Vec4{Float32}(0.2f0, 0.2f0, 0.2f0, 1.0f0))),
                    FixedSize(Container(
                        Column(
                            Fugl.Text("Preprocesamiento", horizontal_align = :left, style = header_style),
                            IntrinsicRow(
                                FixedSize(
                                    TextButton(
                                        "Preprocesar",
                                        on_click = () -> prepro(),
                                        container_style = normal_style,
                                        hover_style = hover_style,
                                        pressed_style = pressed_style,
                                        interaction_state = button3_interaction[],
                                        on_interaction_state_change = (new_state) -> button3_interaction[] = new_state
                                    ), 150, 100
                                ),
                                FixedSize(Fugl.Text(errpre[], vertical_align = :middle, style = err_style), 100, 100),
                                FixedSize(Fugl.Text(okpre[], vertical_align = :middle, style = ok_style), 100, 100),
                            ),
                            Fugl.Text(outpre[], horizontal_align = :left, vertical_align = :middle, style = file_style)
                        )
                    ),1200,200),
                    HLine(style = SeparatorStyle(line_width = 2.0f0, color = Vec4{Float32}(0.2f0, 0.2f0, 0.2f0, 1.0f0))),
                    FixedSize(Container(
                        Column(
                            Fugl.Text("Asignación", horizontal_align = :left, style = header_style),
                            IntrinsicRow(
                                FixedSize(
                                    TextButton(
                                        "Asignar",
                                        on_click = () -> asignar(),
                                        container_style = normal_style,
                                        hover_style = hover_style,
                                        pressed_style = pressed_style,
                                        interaction_state = button4_interaction[],
                                        on_interaction_state_change = (new_state) -> button4_interaction[] = new_state
                                    ), 150, 100
                                ),
                                FixedSize(Fugl.Text(erras[], vertical_align = :middle, style = err_style), 100, 100),
                                FixedSize(Fugl.Text(okas[], vertical_align = :middle, style = ok_style), 100, 100),
                            ),
                            Fugl.Text(outas[], horizontal_align = :left, vertical_align = :middle, style = file_style),
                            Fugl.Text(outas2[], horizontal_align = :left, vertical_align = :middle, style = file_style),
                        )
                    ),900,250)
                )
            )
        end
        Fugl.run(
            entorno, title="Asignación",window_width_px=600,window_height_px=800
        )
        return nothing
    end

end
