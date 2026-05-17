function modificar_df_actividades!(df_actividades,actividades)
  for act in actividades
    df_actividades.capacidad[act.id] = act.capacidad[]
  end
end

function marcar_inscripciones_ya_asignadas(i, dfs,dia)
  fila = dfs[dia][i,:]
  CUEr = fila.CUE
  for df in dfs
    df[df.CUE .== CUEr, "Estado"] .= "CUE asignado al día $dia"
  end
  end

function construir_df_combos(asignacion, combos)
    filas_asignadas = sort(collect(keys(asignacion)))
    n_asig = length(filas_asignadas)
    max_act = isempty(combos) ? 0 : maximum(length.(combos))

    df_combo = DataFrame()

    for k in 1:max_act
        # CAMBIO AQUÍ: Usamos Vector{Any} para que acepte tanto Strings como Missing
        df_combo[!, Symbol("Actividad$(k)_Tipo")]   = Vector{Any}(missing, n_asig)
        df_combo[!, Symbol("Actividad$(k)_Inicio")] = Vector{Any}(missing, n_asig)
        df_combo[!, Symbol("Actividad$(k)_Fin")]    = Vector{Any}(missing, n_asig)
        df_combo[!, Symbol("Actividad$(k)_Nombre")] = Vector{Any}(missing, n_asig)
    end

    for (r, i) in enumerate(filas_asignadas)
        idx_combo = asignacion[i]

        if idx_combo <= 0 || idx_combo > length(combos)
            continue
        end

        combo = combos[idx_combo]

        for k in 1:max_act
            if k <= length(combo)
                act = combo[k]
                if act isa Almuerzo
                    df_combo[r, Symbol("Actividad$(k)_Nombre")] = "Pausa para almuerzo."
                    df_combo[r, Symbol("Actividad$(k)_Inicio")] = "12:30"
                    df_combo[r, Symbol("Actividad$(k)_Fin")]    = "13:30"
                    df_combo[r, Symbol("Actividad$(k)_Tipo")]   = "Almuerzo"
                else
                    df_combo[r, Symbol("Actividad$(k)_Tipo")]   = string(nameof(typeof(act)))
                    df_combo[r, Symbol("Actividad$(k)_Inicio")] = act.inicio
                    df_combo[r, Symbol("Actividad$(k)_Fin")]    = act.fin
                    df_combo[r, Symbol("Actividad$(k)_Nombre")] = hasproperty(act, :label) ? act.label : "Sin nombre"
                end
            end
        end
    end

    return df_combo
end

function crear_asignacion(F, idx_ins, idx_combo, n, m)
  asignacion = Dict{Int,Int}()
  for i in 1:n
      ui = idx_ins(i)
      for j in 1:m
          vj = idx_combo(j)
          if F[ui, vj] == 1
              asignacion[i] = j
              break
          end
      end
  end
  return asignacion
end

function creador_df_entrega(res, dfs_x_dia, combos_x_dia, ruta_salida)
  hojas = Tuple{String, Vector, Vector{Symbol}}[]
  n_dias = length(dfs_x_dia)

  for dia in 1:n_dias
    df_dia = dfs_x_dia[dia]
    combos_del_dia = vcat(combos_x_dia[dia]...)
    asignacion = res[dia][2]
    n_ins = nrow(df_dia)

    # Ajuste de seguridad para columnas requeridas
    #columnas_totales = ncol(df_dia)
    #columnas_requeridas = vcat(collect(2:min(11, columnas_totales)),
                               #max(1, columnas_totales-1):columnas_totales)
    #columnas_requeridas = unique(columnas_requeridas)

    # Asignados:
    filas_asignadas = sort(collect(keys(asignacion)))

    if !isempty(filas_asignadas)
        df_asignados_base = df_dia[filas_asignadas, :]
        df_info_combos = construir_df_combos(asignacion, combos_del_dia)
        df_asignados = hcat(df_asignados_base, df_info_combos)
        df_asignados[!, :combo_asignado] = [asignacion[i] for i in filas_asignadas]

        push!(hojas, ("Dia_$(dia)_asignados", collect(eachcol(df_asignados)), Symbol.(names(df_asignados))))
    end

    # No asignados:
    mask_asig = falses(n_ins)
    mask_asig[filas_asignadas] .= true
    df_no_asignados = df_dia[.!mask_asig, :]

    push!(hojas, ("Dia_$(dia)_no_asignados", collect(eachcol(df_no_asignados)), Symbol.(names(df_no_asignados))))
  end

  XLSX.writetable(ruta_salida, hojas; overwrite=true)
end