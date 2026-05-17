labels_almuerzo = Dict( #se podria tomar desde el excel de actividades. #REVISAR
  "LUNES" => "No hay label para el dia Lunes.",
  "MARTES" => "No hay label para el dia Martes.",
  "MIERCOLES" => "No hay label para el dia Miércoles.",
  "JUEVES" => "No hay label para el dia Jueves.",
  "VIERNES" => "No hay label para el dia Viernes.",
  "SABADO" => "No hay label para el dia Sabado.",
  "DOMINGO" => "No hay label para el dia Domingo."
)

#-------------------------------------------------------------------------------

function crear_actividad(fila,i)
  id = i
  cap = fila.capacidad
  cap_int = Ref(cap isa Integer ? cap : Int(round(cap)))


  if fila.Tipo == "CHARLA"
      return Charla(fila.dia, fila.Inicio, fila.Fin, cap_int, fila.turno, fila.label,id)
  elseif fila.Tipo == "TALLER"
      return Taller(fila.dia, fila.Inicio, fila.Fin, cap_int, fila.turno, fila.label,id)
  elseif fila.Tipo == "VISITA"
      return Visita(fila.dia, fila.Inicio, fila.Fin, cap_int, fila.turno, fila.label,id)
  elseif fila.Tipo == "ESTACIONES"
      return Estaciones(fila.dia, fila.Inicio, fila.Fin, cap_int, fila.turno, fila.label,id)
  else
      error("Tipo no reconocido: $(fila.Tipo)")
  end

end

#-------------------------------------------------------------------------------
#Con esta funcion se crean los combos de JC combinando los combos de TM y TT mas el almuerzo
function combinar_turnos(combos_TM, combos_TT; capacidad_almuerzo=999999)
    if isempty(combos_TM) || isempty(combos_TT)
        return []
    end


    dia = combos_TM[1][1].dia
    lab = labels_almuerzo[dia]
    almuerzo = Almuerzo(dia, Ref(capacidad_almuerzo), lab)

    res = []

    for com_M in combos_TM
        for com_T in combos_TT
            push!(res, vcat(com_M, [almuerzo], com_T))
        end
    end

    return res
end


#-------------------------------------------------------------------------------
#Se crean todos los combos posibles
function consturir_combos(actividades, N = 1)

    acts = sort(actividades, by = x -> x.inicio)

    combos = []

    function dfs(actual_combo, restantes)
        if length(actual_combo) >= N
            push!(combos, copy(actual_combo))
        end
        for (i, act) in enumerate(restantes)
            if isempty(actual_combo) || espera_aceptable(last(actual_combo).fin,act.inicio)
                dfs([actual_combo... , act], restantes[i+1:end])
            end
        end
    end

    dfs([], acts)
    return combos
end

#-------------------------------------------------------------------------------

function agrupar_por_dia(lista::Vector{<:ActividadGeneral})
    dias = Dict{String, Vector{ActividadGeneral}}()

    for act in lista
        push!(get!(dias, act.dia, ActividadGeneral[]), act)
    end

    dias_ordenados = sort(collect(keys(dias)), by = d -> orden[uppercase(d)])

    return [dias[d] for d in dias_ordenados]
end
#-------------------------------------------------------------------------------
function actividades_distintas(combo)
    vistos = Set{Tuple{DataType,String}}()

    for act in combo
        if act isa Almuerzo
            continue
        end

        label = hasproperty(act, :label) ? strip(uppercase(String(act.label))) : ""
        clave = (typeof(act), label)

        if clave in vistos
            return false
        end

        push!(vistos, clave)
    end

    return true
end

#-------------------------------------------------------------------------------

function separar_por_turno(lista)
    manana = [act for act in lista if act.turno == "MAÑANA"]
    tarde  = [act for act in lista if act.turno == "TARDE"]
    return manana, tarde
end

#-------------------------------------------------------------------------------

function filtrar_combinaciones(combinaciones; max_talleres = 2, max_visitas = 1, max_stands = 3, charlas_cons = 1,taller_y_visita = false)
    filter!(
        combo -> N_actividad(combo, Taller) <= max_talleres && #no haya mas de max_talleres talleres
        N_actividad(combo, Visita) <= max_visitas && #no haya mas de max_visitas visitas
        N_actividad(combo, Estaciones) <= max_stands && #no haya mas de max_stands stands
		    (taller_y_visita || !TyV(combo)) && #no haya taller y visita
		    charlas_consecutivas(combo) <= charlas_cons &&# no haya mas de "charlas_cons" charlas consecutivas
        actividades_distintas(combo)
        , combinaciones
        )
end

#-------------------------------------------------------------------------------

function N_actividad(combo, T::Type)
    contador = 0

    for act in combo
        if act isa T
            contador += 1
        end
    end
    return contador
end

function TyV(combo)

    return (N_actividad(combo, Taller) != 0 && N_actividad(combo, Visita) != 0 )

end

#-------------------------------------------------------------------------------

function charlas_consecutivas(combo)
    max_cons = 0
    actual = 0
    for act in combo
        if act isa Charla
            actual += 1
            max_cons = max(max_cons, actual)
        else
            actual = 0
        end
    end
    return max_cons
end

#-------------------------------------------------------------------------------
#=Nuevo:
function prioridad_combo(combo)
    n_talleres = N_actividad(combo, Taller)
    n_visitas  = N_actividad(combo, Visita)
    n_charlas = N_actividad(combo, Charla)

    if

    elseif n_talleres > 0 && n_visitas > 0
        return 0
    elseif n_talleres > 0 || n_visitas > 0
        return 1
    else
        return 2
    end
end

function ordenar_combos(combinaciones)
    return sort(combinaciones; by=prioridad_combo, alg=Base.Sort.MergeSort)
end
=#
function prioridad_combo(combo)
    n_charlas  = N_actividad(combo, Charla)
    n_talleres = N_actividad(combo, Taller)
    n_visitas  = N_actividad(combo, Visita)

    tiene_las_3 = (n_charlas > 0 && n_talleres > 0 && n_visitas > 0)
    tipos_presentes = (n_charlas > 0) + (n_talleres > 0) + (n_visitas > 0)
    total_prioritarias = n_charlas + n_talleres + n_visitas

    return (
        -Int(tiene_las_3),     # primero los que tienen charla+taller+visita
        -tipos_presentes,      # luego más tipos distintos presentes
        -total_prioritarias,   # luego más cantidad total de actividades prioritarias
        -n_talleres,           # desempate: más talleres
        -n_visitas,            # luego más visitas
        -n_charlas             # luego más charlas
    )
end

function ordenar_combos(combinaciones)
    return sort(combinaciones; by = prioridad_combo, alg = Base.Sort.MergeSort)
end
#-------------------------------------------------------------------------------
#HAY que hacer pruebas con esto REVISAR
function espera_aceptable(fin_A, ini_B, minutos_aceptables = 10) #conversar con popu el tiempo de espera, a priori 0
    res = false

    if fin_A <= ini_B && ini_B - fin_A <= Minute(minutos_aceptables)
        res = true
    end

    return res

end

#-------------------------------------------------------------------------------

function lectura_y_creacion(ruta_actividades)

  df = DataFrame(XLSX.readtable(ruta_actividades, 1))

  rename!(df, Dict(
      "tipo de actividad" => "Tipo",
      "Horario de inicio" => "Inicio",
      "Horario de fin" => "Fin",
  ))

  actividades = ActividadGeneral[]

  for i in 1:nrow(df)

    fila = df[i,1:7] ###CANTIDAD DE COLUMNAS CON INFORMACION REELEVANTE
    act = crear_actividad(fila,i)
    push!(actividades,act)

  end

  actividades_x_dia = agrupar_por_dia(actividades)
  n_dias = length(actividades_x_dia)
  combos = [[] for _ in 1:n_dias]
  i = 1

  for actividades_del_dia in actividades_x_dia

    turno_manana, turno_tarde = separar_por_turno(actividades_del_dia)

    combos_turno_manana = consturir_combos(turno_manana,3) ## el numero es para el tamaño de los combos
    combos_turno_tarde = consturir_combos(turno_tarde,2)
    combos_jornada_completa = combinar_turnos(combos_turno_manana, combos_turno_tarde) ##

    filtrar_combinaciones(combos_turno_manana)
    filtrar_combinaciones(combos_turno_tarde) #lo hace in-place
    filtrar_combinaciones(combos_jornada_completa,taller_y_visita = true)

    combos_turno_manana = ordenar_combos(combos_turno_manana)
    combos_turno_tarde = ordenar_combos(combos_turno_tarde)
    combos_jornada_completa = ordenar_combos(combos_jornada_completa)


    combos[i] = [combos_jornada_completa, combos_turno_manana, combos_turno_tarde]
    i +=1

  end

  return combos , actividades, df

end

