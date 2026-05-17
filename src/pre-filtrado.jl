
#------------------------------------------------------------------------------
#Seccion prioridad:
function parse_lista_int(x)
    if ismissing(x) || x == ""
        return nothing
    elseif x isa Integer
        return [Int(x)]
    elseif x isa AbstractFloat
        if isinteger(x)
            return [Int(round(x))]
        else
            error("Se esperaba un entero pero vino un float no entero: $x")
        end
    elseif x isa AbstractString
        return parse.(Int, strip.(split(x, ",")))
    else
        error("Tipo no soportado en parse_lista_int: $(typeof(x)) con valor $x")
    end
end

#-------------------------------------------------------------------------------

function construir_criterios(ruta)

    df = DataFrame(XLSX.readtable(ruta, 2))

    criterios = Function[]

    for r in eachrow(df)

        if !ismissing(r.resto) && (uppercase(String(r.resto)) == "SI" || uppercase(String(r.resto)) == "SÍ"  ) #si pusieron resto = ok terminamos...
            push!(criterios, e -> true)
            continue
        end

        cursos = parse_lista_int(r.curso)
        orientacion = parse_lista_int(r.orientacion)
        #escuela_uba = r.escuela_uba

        vmin = ismissing(r.vulnerabilidad_min) ? nothing : r.vulnerabilidad_min #si hay algo en vulnerabilidad guardalo
        jornada = ismissing(r.jornada_completa) ? nothing : r.jornada_completa #lo usariamos si le queremos dar prioridad a gente q viene de lejos

        push!(criterios, e -> begin

            ok = true

            if cursos !== nothing
                ok &= e.curso in cursos
            end

            if orientacion !== nothing
                ok &= e.orientacion in orientacion
            end

            if vmin !== nothing
                ok &= e.vulnerabilidad >= vmin
            end

            if jornada !== nothing
                ok &= e.Jornada_completa == jornada
            end

            #if escuela_uba !== nothing
            #  ok &= e.CUE in lista_uba
            #end

            return ok
        end)

    end

    return criterios

end
#-------------------------------------------------------------------------------

function agregar_prioridad!(df::DataFrame, criterios; col::Symbol=:prioridad, default::Int=length(criterios))

    pr = Vector{Int}(undef, nrow(df))

    for r in 1:nrow(df)
        if ismissing(df[r, :curso])
            pr[r] = default
            continue
        end

        p = default
        fila = df[r, :]
            for (k, criterio) in enumerate(criterios)
    val = criterio(fila)

  end
        for (k, criterio) in enumerate(criterios)
            if criterio(fila)
                p = k
                break
            end
        end
        pr[r] = p
    end

    df[!, col] = pr
    return df
end

#-------------------------------------------------------------------------------=#

function primer_numero(texto::AbstractString)
  m = match(r"\d+", texto)
  return isnothing(m) ? missing : parse(Int, m.match)
end

#------------------------------------------------------------------------------
#Seccion jornada efectiva:

function agregar_turno_efectivo!(
    df;
    col_turno::String = "turno solicitado",
    col_ubicacion::Symbol = :Partido
)

    turno_solicitado = uppercase.(strip.(coalesce.(df[!, col_turno], "")))
    ubicacion = uppercase.(strip.(coalesce.(df[!, col_ubicacion], "")))

    habilitada_geo = (ubicacion .!= "CIUDAD AUTÓNOMA DE BUENOS AIRES (CABA)") .&
                     (ubicacion .!= "PARTIDOS DEL GRAN BUENOS AIRES - ZONA NORTE (PBA)") .&
                     (ubicacion .!= "CABA") .&
                     (ubicacion .!= "ÁREA METROPOLITANA DE BUENOS AIRES") .&
                     (ubicacion .!= "PARTIDOS DEL GRAN BUENOS AIRES-NORTE") #Depende del forms

    solicita_jc = turno_solicitado .== "JORNADA COMPLETA: TURNO COMPLETO (9:00 A 16.00 HS.)"
    solicita_tm = turno_solicitado .== "JORNADA SIMPLE: SÓLO TURNO MAÑANA (9:00 A 12.30 HS.)"
    #solicita_tt = turno_solicitado .== "JORNADA SIMPLE: SÓLO TURNO TARDE (12.30 A 16:00 HS.)"
    solicita_cualquiera = turno_solicitado .== "JORNADA SIMPLE: TURNO MAÑANA (9:00 A 12.30 HS.) Ó TURNO TARDE (12.30 A 16:00 HS.)"

    df[!, "Jornada Completa"] = ifelse.(
        solicita_jc .& habilitada_geo,
        "Admitida",
        ifelse.(
            solicita_jc,
            "No admitida",
            "No"
        )
    )

    df[!, "Turno efectivo"] = ifelse.(
        solicita_jc .& habilitada_geo,
        "Jornada Completa",
        ifelse.(
            solicita_jc,
            "Turno Tarde",
            ifelse.(
                solicita_tm,
                "Turno Mañana",
                "Turno Tarde"
            )
        )
    )

    return df
end
#-------------------------------------------------------------------------------

function separar_repetidos(
    df::DataFrame;
    dia_col::String = "fecha solicitada",
    cue_col::Symbol = :CUE,
    dni_col::Symbol = :DNI_Docente,
    prioridad_col::Symbol = :prioridad,
    estado_col::String = "Estado",
)
    n = nrow(df)

    dias = coalesce.(df[!, dia_col], "")
    cues = coalesce.(df[!, cue_col], "")
    dnis = coalesce.(df[!, dni_col], "")

    # prioridad grande para missing
    prioridades = [
        ismissing(x) ? typemax(Int) : Int(round(x))
        for x in df[!, prioridad_col]
    ]

    orden_filas = sortperm(1:n, by = i -> (dias[i], prioridades[i], i))

    vistos_cue_dia = Set{Tuple{Any,Any}}()
    vistos_dni_dia = Set{Tuple{Any,Any}}()

    keep = trues(n)

    for i in orden_filas
        motivos = String[]

        dia = dias[i]
        cue = cues[i]
        dni = dnis[i]

        if cue != ""
            clave_cue = (cue, dia)
            if clave_cue in vistos_cue_dia
                push!(motivos, "CUE repetido")
            else
                push!(vistos_cue_dia, clave_cue)
            end
        end

        if dni != ""
            clave_dni = (dni, dia)
            if clave_dni in vistos_dni_dia
                push!(motivos, "Docente repetido")
            else
                push!(vistos_dni_dia, clave_dni)
            end
        end

        if !isempty(motivos)
            keep[i] = false
            df[i, estado_col] = join(motivos, "; ")
        end
    end

    df_filtrado = df[keep, :]
    repetidos_a_chequear = df[.!keep, :]

    return df_filtrado, repetidos_a_chequear
end
#-------------------------------------------------------------------------------

function primer_filtrado(ruta_crudo, ruta_actividades)

  #...........................................LEO LOS ARCHIVOS:..................................................

  df = DataFrame(XLSX.readtable(ruta_crudo, 1))
  df_actividades = DataFrame(XLSX.readtable(ruta_actividades, 1))
  criterios = construir_criterios(ruta_actividades)

  #........................................Chequeo que esten las columnas que necesita "Inscripciones.jl":...................................................
  control_prefiltrado(df, df_actividades) ## Falta afilar los controles para evitar errores <------------------------------------- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  rename!(df, :"apellido y nombre del/la docente responsable de la visita" => "DNI_Docente")
  rename!(df, Dict(
    "codigo unico de escuela (cue)" => "CUE",
    "porcentaje aproximado de estudiantes de familias de bajos recursos" => "vulnerabilidad",
    "ubicacion de la escuela" => "Partido",
    #"dni del/la docente responsable de la visita" => "DNI_Docente"
  ))
  #df.Docente = strip.(uppercase.(coalesce.(df.Docente, ""))) #no me acuerdo para que hago esto

  #........................................Seccion de prioridad .........................................................

    curso = [!ismissing(x) ? primer_numero(x) : missing for x in df[:,"curso que asistira"]]
    orientacion = [!ismissing(x) ? primer_numero(x) : missing for x in df[:, "tipo de institucion educativa y orientacion"]]

    df.curso = curso
    df.orientacion = orientacion
    agregar_prioridad!(df, criterios)
    sort!(df, :prioridad)

  #........................................Creo la columna Jornada Completa y marco los repetidos: ...................................................

  agregar_turno_efectivo!(df)
  df[!, "Estado"] = fill("Disponible", nrow(df))
  df, repetidos_a_chequear = separar_repetidos(df)


 XLSX.writetable(
    "resultado.xlsx",
    "Filtrados" => Tables.columntable(df),
    "Repetidos" => Tables.columntable(repetidos_a_chequear);
    overwrite=true
)

end

