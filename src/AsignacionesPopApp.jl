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
    include("main.jl")

const ANCHO_WIN = 950
const ALTO_WIN = 760

const ANCHO_CONT = 880
const ANCHO_CONT_CHICO = ANCHO_CONT ÷ 2 - 20

const ALTO_CONT_SUP = 145

const ALTO_CONT_PRE = 165
const ALTO_CONT_ASIG = 420

const ANCHO_BTN_IM = 88
const ALTO_BTN_IM = 48

const ANCHO_BTN_TXT = 180
const ALTO_BTN_TXT = 50

const ANCHO_ESTADO = 45


    function (@main)(ARGS)

        button1_interaction = Ref(InteractionState())
        button2_interaction = Ref(InteractionState())
        button3_interaction = Ref(InteractionState())
        button4_interaction = Ref(InteractionState())
        button5_interaction = Ref(InteractionState())
        button6_interaction = Ref(InteractionState())

        ## Estilos
        # Estilos de botón
        normal_style = ContainerStyle(
            background_color = Vec4f(0.9, 0.9, 0.9, 1.0),
            border_color = Vec4f(0.8, 0.8, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 1.0f0,
            corner_radius = 6.0f0
        )

        hover_style = ContainerStyle(
            background_color = Vec4f(0.7, 0.7, 0.7, 1.0),
            border_color = Vec4f(0.8, 0.8, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 1.0f0,
            corner_radius = 6.0f0
        )

        pressed_style = ContainerStyle(
            background_color = Vec4f(0.85, 0.85, 0.95, 1.0),
            border_color = Vec4f(0.8, 0.8, 0.8, 1.0),
            border_width = 2.0f0,
            padding = 1.0f0,
            corner_radius = 6.0f0
        )

        # Estilos de texto
        header_style = TextStyle(
            color = Vec4f(0.1, 0.5, 0.8, 1.0),
            size_px = 32
        )
        file_style = TextStyle(
            color = Vec4f(0.4, 0.4, 0.4, 1.0),
            size_px = 12
        )
        err_style = TextStyle(
            color = Vec4f(1.0, 0.0, 0.0, 1.0),
            size_px = 16
        )
        ok_style = TextStyle(
            color = Vec4f(0.0, 1.0, 0.0, 1.0),
            size_px = 16
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
        archact = Ref("[Actividades]")
        archpre = Ref("[Inscriptos]")

        function ruta_corta(ruta)
            if isempty(ruta)
                return ""
            end

            carpeta = basename(dirname(ruta))
            archivo = basename(ruta)

            return joinpath(carpeta, archivo)
        end

        ### Preprocesado
        function prepro()
            try
                df, repetidos_a_chequear = primer_filtrado(esc[], act[])
                okpre[] = "✔"
                outpre[] = "Preprocesado con éxito. Guarde los resultados."
                sleep(1.0)
                pre[] = NativeFileDialog.save_file()
                archpre[] = pre[]
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

        function leeract()
            act[] = NativeFileDialog.pick_file()
            archact[] = act[]
        end

        function elegir_archact()
            ruta = NativeFileDialog.pick_file()
            if ruta != ""
                archact[] = ruta
            end
        end

        function elegir_archpre()
            ruta = NativeFileDialog.pick_file()
            if ruta != ""
                archpre[] = ruta
            end
        end

        ### Asignación
        function asignar()
            try
                res,dfs_x_dia,combos_x_dia = realizar_asignacion(archpre[], archact[])
                okas[] = "✔"
                outas[] = "Asignación existosa."
                sleep(1.0)
                destino[] = NativeFileDialog.save_file()
                creador_df_entrega(res, dfs_x_dia, combos_x_dia, destino[])
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

                    # ============================================================
                    # FILA SUPERIOR: Escuelas y Actividades lado a lado
                    # ============================================================
                    FixedSize(
                        Container(
                            IntrinsicRow(

                                # ------------------------------------------------
                                # Bloque Escuelas
                                # ------------------------------------------------
                                FixedSize(
                                    Container(
                                        IntrinsicColumn(
                                            Fugl.Text(
                                                "Escuelas",
                                                horizontal_align = :left,
                                                style = header_style
                                            ),

                                            FixedSize(
                                                IntrinsicRow(
                                                    FixedSize(
                                                        IconButton(
                                                            im,
                                                            on_click = () -> esc[] = NativeFileDialog.pick_file(),
                                                            container_style = normal_style,
                                                            hover_style = hover_style,
                                                            pressed_style = pressed_style,
                                                            interaction_state = button1_interaction[],
                                                            on_interaction_state_change =
                                                                (new_state) -> button1_interaction[] = new_state
                                                        ),
                                                        ANCHO_BTN_IM,
                                                        ALTO_BTN_IM
                                                    ),

                                                    Fugl.Text(
                                                        ruta_corta(esc[]),
                                                        horizontal_align = :left,
                                                        vertical_align = :middle,
                                                        wrap_text = false,
                                                        style = file_style
                                                    );

                                                    spacing = 12.0
                                                ),
                                                ANCHO_CONT_CHICO,
                                                ALTO_BTN_IM
                                            );

                                            spacing = 12.0
                                        )
                                    ),
                                    ANCHO_CONT_CHICO,
                                    ALTO_CONT_SUP
                                ),

                                # ------------------------------------------------
                                # Bloque Actividades
                                # ------------------------------------------------
                                FixedSize(
                                    Container(
                                        IntrinsicColumn(
                                            Fugl.Text(
                                                "Actividades",
                                                horizontal_align = :left,
                                                style = header_style
                                            ),

                                            FixedSize(
                                                IntrinsicRow(
                                                    FixedSize(
                                                        IconButton(
                                                            im,
                                                            on_click = leeract,
                                                            container_style = normal_style,
                                                            hover_style = hover_style,
                                                            pressed_style = pressed_style,
                                                            interaction_state = button2_interaction[],
                                                            on_interaction_state_change =
                                                                (new_state) -> button2_interaction[] = new_state
                                                        ),
                                                        ANCHO_BTN_IM,
                                                        ALTO_BTN_IM
                                                    ),

                                                    Fugl.Text(
                                                        ruta_corta(act[]),
                                                        horizontal_align = :left,
                                                        vertical_align = :middle,
                                                        wrap_text = false,
                                                        style = file_style
                                                    );

                                                    spacing = 12.0
                                                ),
                                                ANCHO_CONT_CHICO,
                                                ALTO_BTN_IM
                                            );

                                            spacing = 12.0
                                        )
                                    ),
                                    ANCHO_CONT_CHICO,
                                    ALTO_CONT_SUP
                                );

                                spacing = 12.0
                            )
                        ),
                        ANCHO_CONT,
                        ALTO_CONT_SUP
                    ),

                    # ============================================================
                    # BLOQUE PREPROCESAMIENTO
                    # ============================================================
                    FixedSize(
                        Container(
                            IntrinsicColumn(
                                Fugl.Text(
                                    "Preprocesamiento",
                                    horizontal_align = :left,
                                    style = header_style
                                ),

                                FixedSize(
                                    IntrinsicRow(
                                        FixedSize(
                                            TextButton(
                                                "Preprocesar",
                                                on_click = prepro,
                                                container_style = normal_style,
                                                hover_style = hover_style,
                                                pressed_style = pressed_style,
                                                interaction_state = button3_interaction[],
                                                on_interaction_state_change =
                                                    (new_state) -> button3_interaction[] = new_state
                                            ),
                                            ANCHO_BTN_TXT,
                                            ALTO_BTN_TXT
                                        ),

                                        FixedSize(
                                            Fugl.Text(
                                                errpre[],
                                                vertical_align = :middle,
                                                style = err_style
                                            ),
                                            ANCHO_ESTADO,
                                            ALTO_BTN_TXT
                                        ),

                                        FixedSize(
                                            Fugl.Text(
                                                okpre[],
                                                vertical_align = :middle,
                                                style = ok_style
                                            ),
                                            ANCHO_ESTADO,
                                            ALTO_BTN_TXT
                                        );

                                        spacing = 10.0
                                    ),
                                    ANCHO_CONT,
                                    ALTO_BTN_TXT
                                ),

                                Fugl.Text(
                                    outpre[],
                                    horizontal_align = :left,
                                    vertical_align = :middle,
                                    wrap_text = false,
                                    style = file_style
                                );

                                spacing = 12.0
                            )
                        ),
                        ANCHO_CONT,
                        ALTO_CONT_PRE
                    ),
                    

                    # ============================================================
                    # BLOQUE ASIGNACIÓN
                    # ============================================================
                    FixedSize(
                        Container(
                            IntrinsicColumn(
                                Fugl.Text(
                                    "Asignación",
                                    horizontal_align = :left,
                                    style = header_style
                                ),

                                IntrinsicRow(
                                    FixedSize(
                                        IconButton(
                                            im,
                                            on_click = elegir_archact,
                                            container_style = normal_style,
                                            hover_style = hover_style,
                                            pressed_style = pressed_style,
                                            interaction_state = button5_interaction[],
                                            on_interaction_state_change =
                                                (new_state) -> button5_interaction[] = new_state
                                        ),
                                        ANCHO_BTN_IM,
                                        ALTO_BTN_IM
                                    ),

                                    Fugl.Text(
                                        ruta_corta(archact[]),
                                        horizontal_align = :left,
                                        vertical_align = :middle,
                                        wrap_text = false,
                                        style = file_style
                                    );

                                    spacing = 14.0
                                ),

                                IntrinsicRow(
                                    FixedSize(
                                        IconButton(
                                            im,
                                            on_click = elegir_archpre,
                                            container_style = normal_style,
                                            hover_style = hover_style,
                                            pressed_style = pressed_style,
                                            interaction_state = button6_interaction[],
                                            on_interaction_state_change =
                                                (new_state) -> button6_interaction[] = new_state
                                        ),
                                        ANCHO_BTN_IM,
                                        ALTO_BTN_IM
                                    ),

                                    Fugl.Text(
                                        ruta_corta(archpre[]),
                                        horizontal_align = :left,
                                        vertical_align = :middle,
                                        wrap_text = false,
                                        style = file_style
                                    );

                                    spacing = 14.0
                                ),

                                IntrinsicRow(
                                    FixedSize(
                                        TextButton(
                                            "Asignar",
                                            on_click = asignar,
                                            container_style = normal_style,
                                            hover_style = hover_style,
                                            pressed_style = pressed_style,
                                            interaction_state = button4_interaction[],
                                            on_interaction_state_change =
                                                (new_state) -> button4_interaction[] = new_state
                                        ),
                                        ANCHO_BTN_TXT,
                                        ALTO_BTN_TXT
                                    ),

                                    FixedSize(
                                        Fugl.Text(
                                            erras[],
                                            vertical_align = :middle,
                                            style = err_style
                                        ),
                                        ANCHO_ESTADO,
                                        ALTO_BTN_TXT
                                    ),

                                    FixedSize(
                                        Fugl.Text(
                                            okas[],
                                            vertical_align = :middle,
                                            style = ok_style
                                        ),
                                        ANCHO_ESTADO,
                                        ALTO_BTN_TXT
                                    );

                                    spacing = 10.0
                                ),

                                Fugl.Text(
                                    outas[],
                                    horizontal_align = :left,
                                    vertical_align = :middle,
                                    wrap_text = false,
                                    style = file_style
                                ),

                                Fugl.Text(
                                    outas2[],
                                    horizontal_align = :left,
                                    vertical_align = :middle,
                                    wrap_text = false,
                                    style = file_style
                                );

                                spacing = 12.0
                            )
                        ),
                        ANCHO_CONT,
                        ALTO_CONT_ASIG
                    )
                )
            )
        end
        Fugl.run(
            entorno, title="Asignación",window_width_px=ANCHO_WIN,window_height_px=ALTO_WIN
        )
        return nothing
    end

end
