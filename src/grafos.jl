function combo2respuesta(df,i,j,indicador_mañana,indicador_tarde)

  if j<1 || i < 1 || i > nrow(df)
    println("error en los indices i: $i y/0 j:$j")

  elseif 1 <= j < indicador_mañana #combo jornada completa
    if (df[i,"Jornada Completa"] == "Si") && (df[i,"Estado"] == "Disponible" )
      return 1
    else
      return 0
    end

  elseif indicador_mañana <= j < indicador_tarde #combo turno mañana
    if (df[i,"TM"] == "Si" || df[i,"TM"] == "Sí") && df[i,"TT"] == "No" && (df[i, "Estado"] == "Disponible")
      return 1
    else
      return 0
    end

  elseif indicador_tarde <= j #combo turno tarde
    if (df[i,"TT"] == "Si" || df[i,"TT"] == "Sí") && (df[i,"Estado"] == "Disponible")
      return 1
    else
      return 0
    end
  end
end

#-------------------------------------------------------------------------------

function crear_grafo_multi_curso(df, combos_x_turno; n_inscripciones=nrow(df)) ##CONSULTA PARA IGNA: el nrow(df) entiende q es del df q esta en la primera entrada?

    indicador_mañana = length(combos_x_turno[1])+1
    indicador_tarde = length(combos_x_turno[2]) + indicador_mañana
    combos = vcat(combos_x_turno...)

    n = n_inscripciones
    m = length(combos)

    s = 1
    idx_ins(i) = 1 + i
    idx_combo(j) = 1 + n + j
    t = 2 + n + m
    N = t

    g = DiGraph(N)
    cap = spzeros(Int, N, N)

    # helper: agrega u->v y también v->u al grafo (capacidad solo en u->v)
    function add_edge_with_reverse!(g, cap, u, v, c_uv::Int)
        add_edge!(g, u, v)
        add_edge!(g, v, u)      # <-- arista inversa para poder recorrer residual reverso
        cap[u, v] = c_uv        # capacidad forward
        return nothing
    end

    # s -> curso (1 combo por curso)
    for i in 1:n
        add_edge_with_reverse!(g, cap, s, idx_ins(i), 1)
    end

    # combo -> t (muchos cursos por combo)
    for j in 1:m
        add_edge_with_reverse!(g, cap, idx_combo(j), t, nrow(df))
    end


    # curso -> combo si acepta
    for i in 1:n, j in 1:m
        if combo2respuesta(df,i,j,indicador_mañana,indicador_tarde) == 1
            add_edge_with_reverse!(g, cap, idx_ins(i), idx_combo(j), 1)
        end
    end

    return g, cap, indicador_mañana, indicador_tarde,idx_ins, idx_combo, s, t, n, m
end

#------------------------------------------------------------------------------

function agregar_curso_al_combo(u, v, n, df, combos)
  if u - 1 > n ||  v < n + 1
    println("error en los indices u: $u y v:$v")
  end
  """se espera que u sea un id_curso y v un id_combo"""
  u_idx = u - 1
  alumnos = df[u_idx, "Alumnos"]
  combo = combos[v-n-1]
  for act in combo
    act.capacidad[] = act.capacidad[] - alumnos

    if act.capacidad[] < 0 #por las dudas, aunque no deberia llegar a llamarse a esta funcion si alumnos > capacidad.
      println("error, nueva capacidad negativa.")
    end
  end
end

#------------------------------------------------------------------------------

function quitar_curso_del_combo!(u, v, n, df, combos)
    """se espera que u sea un id_curso y v un id_combo"""

    # (opcional pero recomendado) chequeos básicos de índices
    if !(2 <= u <= n + 1)
        error("u=$u no parece ser un id de curso válido (esperaba 2..$(n+1))")
    end
    combo_idx = v - n - 1
    if !(1 <= combo_idx <= length(combos))
        error("v=$v no parece ser un id de combo válido (combo_idx=$combo_idx, length(combos)=$(length(combos)))")
    end

    u_idx = u - 1
    alumnos = df[u_idx, "Alumnos"]

    combo = combos[combo_idx]
    for act in combo
        act.capacidad[] = act.capacidad[] + alumnos
    end

    return nothing
end

#------------------------------------------------------------------------------

es_curso(x, n) = 2 <= x <= n + 1
es_combo(x, n, combos) = 1 <= (x - n - 1) <= length(combos)

