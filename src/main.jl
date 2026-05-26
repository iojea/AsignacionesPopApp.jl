function main(ruta_inscripciones, ruta_actividades, dia = 0)
    cantidad_de_asignados = 0
    df_criterios = DataFrame(XLSX.readtable(ruta_actividades, 2))

    dfs_x_dia = Filtrar_inscripciones(ruta_inscripciones) #deberia crear aca un diccionario que identifique dia 1 = 3 y asi por ejemplo si el primer dia es un miercoles

    combos_x_dia, actividades, df_actividades, actividades_cuarto_slot = lectura_y_creacion(ruta_actividades) #NUEVO, AGREGAR

    if dia ∈ 1:7

        g, cap, indicador_mañana, indicador_tarde, idx_ins, idx_combo, s, t, n, m = crear_grafo_multi_curso(dfs_x_dia[dia],combos_x_dia[dia]) #por ahora se usa con el numero de dia del evento, no de la semana

        f,F = maximum_flow(g, s, t, cap,dfs_x_dia[dia],combos_x_dia[dia],algorithm=EdmondsKarpModificado())

        modificar_df_actividades!(df_actividades, actividades)
        XLSX.writetable(
        "Actividades_salida.xlsx",
        "Actividades" => Tables.columntable(df_actividades),
        "Criterios" => Tables.columntable(df_criterios),
        overwrite=true
    )

        println("Se asignaron a $f de $cantidad_inscriptos inscriptos en la $d ° asignación.")

        XLSX.writetable(
        "Actividades_salida.xlsx",
        "Actividades" => Tables.columntable(df_actividades),
        "Criterios" => Tables.columntable(df_criterios),
        overwrite=true)

        creador_df_entrega(res, dfs_x_dia, combos_x_dia, "asignaciones.xlsx")

        println("Se asignaron a $cantidad_de_asignados inscripciones.")

    elseif dia == 0

        indices_ordenados = sortperm(nrow.(dfs_x_dia))
        dfs_x_dia = dfs_x_dia[indices_ordenados]
        combos_x_dia = combos_x_dia[indices_ordenados]

        cantidad_de_dias = length(dfs_x_dia)

        res = Vector{Tuple{Int64, Dict{Int,Int}}}(undef, cantidad_de_dias)

        for d in 1:cantidad_de_dias
            cantidad_inscriptos = nrow(dfs_x_dia[d])
            println("se empieza a armar el grafo")
            g, cap, indicador_mañana, indicador_tarde, idx_ins, idx_combo, s, t, n, m = crear_grafo_multi_curso(dfs_x_dia[d],combos_x_dia[d]) #por ahora se usa con el numero de dia del evento, no de la semana
            println("se resuelve el problema")
            f,F = maximum_flow(g, s, t, cap,dfs_x_dia[d],combos_x_dia[d],algorithm=EdmondsKarpModificado())
            println("Se escribe la asignacion")
            asignacion = crear_asignacion(F, idx_ins,  idx_combo,n,m)
            res[d] = (f, asignacion)
            cantidad_de_asignados += f

            #for i in sort(collect(keys(asignacion)))
            # marcar_inscripciones_ya_asignadas(i, dfs_x_dia,d)
            #end

            println("Se asignaron a $f de $cantidad_inscriptos inscriptos en la $d ° asignación.")
        end

        res, combos_x_dia = agregar_cuarto_slot(res, combos_x_dia,dfs_x_dia, actividades_cuarto_slot)
        modificar_df_actividades!(df_actividades, actividades) # antes esto se hacia con un for por d en dias, creo q es innecesario pero REVISAR!!!####

        #creacion excel de actividades residuales:
        XLSX.writetable(
        "Actividades_salida.xlsx",
        "Actividades" => Tables.columntable(df_actividades),
        "Criterios" => Tables.columntable(df_criterios),
        overwrite=true)

        #creacion excel de asignaciones realizadas:
        creador_df_entrega(res, dfs_x_dia, combos_x_dia, "asignaciones.xlsx")

        println("Se asignaron a $cantidad_de_asignados inscripciones.")
    end
    return combos_x_dia
end