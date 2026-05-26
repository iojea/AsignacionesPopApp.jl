function completar_combo(combo,cuarto_slot)
  """
  le agrega al "combo" el "cuarto_slot" en el lugar correspondiente
  """
  if length(combo) == 2 #entonces es un combo de turno tarde
    push!(combo, combo[2]) #copio la 2da actividad al puesto 3
    combo[2] = combo[1]
    combo[1] = cuarto_slot
  elseif length(combo) == 6 # 3 actividades tm + almuerzo  +  2 de turno tarde
    push!(combo,combo[6]) #repito el ultimo combo en el lugar 7
    combo[6] = combo[5]
    combo[5] = cuarto_slot
  end
  return combo
end

#------------------------------------------------------------------------------#

function opcion_con_mas_capacidad(combo, actividades_cuarto_slot, cant_alumnos)
    """
    Dado un combo ya asignado, devuelve la actividad de cuarto slot con mayor
    capacidad disponible, siempre que:
    - no repita label con ninguna actividad ya presente en el combo
    - tenga capacidad suficiente para cant_alumnos

    Además, actualiza in-place la capacidad de la actividad elegida.
    Si no encuentra ninguna opción válida, devuelve nothing.
    """
    cant_alumnos = Int(round(cant_alumnos))

    # labels ya usadas en el combo
    labels_combo = Set(
        strip(uppercase(String(act.label)))
        for act in combo if hasproperty(act, :label)
    )

    mejor_opcion = nothing
    mejor_capacidad = -1

    for act in actividades_cuarto_slot
        label_act = hasproperty(act, :label) ? strip(uppercase(String(act.label))) : ""

        # no repetir actividad ya presente
        if label_act in labels_combo
            continue
        end

        cap = act.capacidad[]

        # debe alcanzar para este curso
        if cap < cant_alumnos
            continue
        end

        # me quedo con la de mayor capacidad
        if cap > mejor_capacidad
            mejor_opcion = act
            mejor_capacidad = cap
        end
    end

    if mejor_opcion === nothing
        return nothing
    end

    # actualizo la capacidad de la actividad elegida
    mejor_opcion.capacidad[] -= cant_alumnos

    return mejor_opcion
end
#------------------------------------------------------------------------------#

function agregar_cuarto_slot(res, combos_x_dia,dfs_x_dia, actividades_cuarto_slot)
  n_dias = length(dfs_x_dia)
  combos_x_dia_unificado = Vector{Any}(undef, n_dias)

  for dia in 1:n_dias
    df_dia = dfs_x_dia[dia]
    indicador_mañana = length(combos_x_dia[dia][1]) + 1
    indicador_tarde = indicador_mañana + length(combos_x_dia[dia][2])
    combos_del_dia = vcat(combos_x_dia[dia]...)
    asignacion = res[dia][2]

    for ins in sort(collect(keys(asignacion)))
      id_combo = asignacion[ins]
      inscripcion = dfs_x_dia[dia][ins,:]

      if  indicador_mañana <= id_combo < indicador_tarde #el combo es de turno mañana
        continue

      else
        cuarto_slot = opcion_con_mas_capacidad(combos_del_dia[id_combo], actividades_cuarto_slot[dia], inscripcion["Alumnos"]) #dado un combo asignado a la ins devuelve la opcion para su cuarto slot con mas capaciadad sin repetir label con las existentes y actualiza la capacidad de la actividad elegida
        copia_combo = deepcopy(combos_del_dia[id_combo]) #es necesario para que si posteriormente otro colegio tiene asignado el combo "id_combo" no se le sobre asignan actividades en el 4to slot.
        nuevo_combo = completar_combo(copia_combo,cuarto_slot)
        push!(combos_del_dia, nuevo_combo) #agregamos el nuevo combo ahora con 4to slot a la lista
        asignacion[ins] = length(combos_del_dia)#id del nuevo_combo
      end
    end

    combos_x_dia_unificado[dia] = combos_del_dia #actualizo combos_x_dia para q contenga todos los nuevos combos con 4to slot
  end


return res, combos_x_dia_unificado

end

#-------------------------------------------------------------------------------

function modificar_df_actividades!(df_actividades,actividades)
  for act in actividades
    df_actividades.capacidad[act.id] = act.capacidad[]
  end
end

#-------------------------------------------------------------------------------

function marcar_inscripciones_ya_asignadas(i, dfs,dia)
  fila = dfs[dia][i,:]
  CUEr = fila.CUE
  for df in dfs
    df[df.CUE .== CUEr, "Estado"] .= "CUE asignado al día $dia"
  end
  end

#-------------------------------------------------------------------------------

function construir_df_combos(asignacion, combos)
    filas_asignadas = sort(collect(keys(asignacion)))
    n_asig = length(filas_asignadas)
    max_act = isempty(combos) ? 0 : maximum(length.(combos))

    df_combo = DataFrame()

    for k in 1:max_act

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

#-------------------------------------------------------------------------------

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

#-------------------------------------------------------------------------------

function creador_df_entrega(res, dfs_x_dia, combos_x_dia, ruta_salida)
  hojas = Tuple{String, Vector, Vector{Symbol}}[]
  n_dias = length(dfs_x_dia)

  for dia in 1:n_dias
    df_dia = dfs_x_dia[dia]
    combos_del_dia = combos_x_dia[dia] #  vcat(combos_x_dia[dia]...) ya no hace falta hacerlo asi porque vienen unificados de "agregar_cuarto_slot"
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