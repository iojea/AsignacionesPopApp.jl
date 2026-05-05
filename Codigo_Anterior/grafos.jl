function combo2respuesta(df, combo, inscripcion)
  for act in combo
    val = df[inscripcion, act.codigo]
    if ismissing(val) #HAY QUE VER COMO CONSIDERAMOS LOS "missing"
      return 1
    elseif val == "No"
      return 0
    end
  end
  return 1
end

#------------------------------------------------------------------------------

function conexion_factible(i,j,n,m)
  res = true
  if ( i < n && j < n ) || ( i > n && j > m )
    res = false
  end

  return res
end
## FALTA CHEQUEAR LOS CASOS BORDE.

#------------------------------------------------------------------------------

function crear_grafo_multi_curso2(df, combos; n_inscripciones=nrow(df), cap_combo=typemax(Int))
    n = n_inscripciones
    m = length(combos)

    s = 1
    idx_ins(i) = 1 + i
    idx_combo(j) = 1 + n + j
    t = 2 + n + m
    N = t

    g = DiGraph(N)
    cap = zeros(Int, N, N)

    # helper: agrega u->v y también v->u al grafo (capacidad solo en u->v)
    function add_edge_with_reverse!(g, cap, u, v, c_uv::Int)
        add_edge!(g, u, v)
        add_edge!(g, v, u)      # <-- arista inversa para poder recorrer residual reverso
        cap[u, v] = c_uv        # capacidad forward
        # cap[v, u] queda 0 (ya lo está por la inicialización)
        return nothing
    end

    # s -> curso (1 combo por curso)
    for i in 1:n
        add_edge_with_reverse!(g, cap, s, idx_ins(i), 1)
    end

    # combo -> t (muchos cursos por combo)
    # si querés, podés usar cap_combo por combo (vector) o un fijo (Int)
    if cap_combo isa AbstractVector
        @assert length(cap_combo) == m
        for j in 1:m
            add_edge_with_reverse!(g, cap, idx_combo(j), t, cap_combo[j])
        end
    else
        for j in 1:m
            # ejemplo: capacidad "enorme" (igual que tu versión)
            add_edge_with_reverse!(g, cap, idx_combo(j), t, nrow(df))
        end
    end

    # curso -> combo si acepta
    for i in 1:n, j in 1:m
        if combo2respuesta(df, combos[j], i) == 1
            add_edge_with_reverse!(g, cap, idx_ins(i), idx_combo(j), 1)
        end
    end

    return g, cap, idx_ins, idx_combo, s, t, n, m
end

#------------------------------------------------------------------------------

##HAY QUE TENER CUIDADO, FETCH_PATH UTILIZA "n" PARA OTRA COSA:

function capacidad_en_combo(combos, v, n) ##Int #recibe el listado de combos del dia "combos", el id del grafo correspondiente a un combo "v" y la cantidad de inscripciones "n"
  combo = combos[v-n-1]
  minimo = 10000
  for act in combo
    if act.capacidad < minimo
      minimo = act.capacidad
    end
  end
  return minimo
end

function hay_capacidad(u, v, n, df, combos) ##BOOL #recibe el id de los nodos "u" y "v", cantidad de inscripciones "n", el df del dia y el listado de combos del dia
  res = true

  if 1 < u <= n + 1
    u_idx = u - 1
    alumnos = df[u_idx, "Cantidad de alumnos"]
    if capacidad_en_combo(combos, v, n) < alumnos
      res = false
    end
  end

  return res
end

function agregar_curso_al_combo(u, v, n, df, combos)
  """se espera que u sea un id_curso y v un id_combo"""
  u_idx = u - 1
  alumnos = df[u_idx, "Cantidad de alumnos"]
  combo = combos[v-n-1]
  for act in combo
    act.capacidad = act.capacidad - alumnos

    if act.capacidad < 0 #por las dudas, aunque no deberia llegar a llamarse a esta funcion si alumnos > capacidad.
      println("error, nueva capacidad negativa.")
    end
  end
end


##Habria que guardarse la capacidad maxima para evitar errores.
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
    alumnos = df[u_idx, "Cantidad de alumnos"]

    combo = combos[combo_idx]
    for act in combo
        act.capacidad = act.capacidad + alumnos
    end

    return nothing
end


#------------------------------------------------------------------------------

es_curso(x, n) = 2 <= x <= n + 1
es_combo(x, n, combos) = 1 <= (x - n - 1) <= length(combos)


#------------------------------------------------------------------------------

#crear aparte el archivo de flujos con el algoritmo modificado.