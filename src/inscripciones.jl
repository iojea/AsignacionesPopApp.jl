orden = Dict(
  "LUNES"=>1,"MARTES"=>2,"MIERCOLES"=>3,"JUEVES"=>4,"VIERNES"=>5,"SABADO"=>6,"DOMINGO"=>7, "MIÉRCOLES"=>3
)


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
    #df_uba = DataFrame(XLSX.readtable(ruta, 3))
    #lista_uba = Set(df_uba[:, "CUE"])


    criterios = Function[]

    for r in eachrow(df)

        if !ismissing(r.resto) && uppercase(String(r.resto)) == "SI" #si pusieron resto = ok terminamos...
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

    return criterios, df

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
    println("criterio $k => ", val)
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

#-------------------------------------------------------------------------------

function split_dfs_x_dia(df, dias)
    dfs_x_dia = []
    for dia in dias
        # filtrar filas exactas (tu dias coincide con "Fecha solicitada")
        df_filtrado = df[coalesce.(df[!, "fecha solicitada"] .== dia, false), :]

        push!(dfs_x_dia, df_filtrado)
    end
    return dfs_x_dia
end

#-------------------------------------------------------------------------------
################################################################################

function Filtrar_inscripciones(ruta_inscripciones, criterios)

  #...........................................LEO LOS ARCHIVOS:..................................................
 #= df = CSV.read(
    ruta_inscripciones,
    DataFrame;
    delim='\t',
    quotechar='"',
    stripwhitespace=true,
    ignorerepeated=false, #cuando detecta multiples "\t\t" los considera como separados
    ignoreemptyrows=true,
    silencewarnings=true   # suprime warnings repetidos
)
=#
  df = DataFrame(XLSX.readtable(ruta_inscripciones, 1))
  #........................................Los limpio y renombro:...................................................

  rename!(df, Dict(
    "nombre oficial y completo de la institucion educativa" => "Nombre del colegio",
    "tipo de institucion educativa y orientacion" => "Tipo de escuela",
    "especifica la orientacion de tu institucion educativa" => "Orientacion",
    "tipo de gestion de la institucion educativa" => "Gestión",
    "direccion de correo electronico donde va a recibir el resultado de la asignacion de vacantes" => "Email",
    "Partido" => "Localidad",
    "cantidad de alumnos que asistiran" => "Alumnos",
    "curso que asistira" => "Años", #Como hago cuando anotan a mas de un año <----------- si tiene un ultimo año ya esta.
    "porcentaje aproximado de estudiantes de familias de bajos recursos" => "vulnerabilidad",
    #="Turno/s solicitado/s [Turno mañana (9:00 a 12.30 hs.)]" => "TM",
    "Turno/s solicitado/s [Turno tarde (12.30 a 16:00 hs.)]" => "TT"
    "Código Único de Escuela (CUE)" => "CUE",
    "Ubicación general de la escuela" => "Partido",
    =#
))
  #agregar_jornada_completa!(df) VER

  #.............................................spliteo el dataframe segun el dia de inscripcion...................................

  dias_aux = unique(collect(skipmissing(df[!, "fecha solicitada"])))
  dias = sort(dias_aux, by = s -> orden[uppercase(strip(first(split(s))))])
  dfs_x_dia = split_dfs_x_dia(df,dias)


  dfs = []
  for df in dfs_x_dia #VER: todo esto lo podria hacer en el primer filtro

    curso = [!ismissing(x) ? primer_numero(x) : missing for x in df.Años]
    orientacion = [!ismissing(x) ? primer_numero(x) : missing for x in df[:,"Tipo de escuela"]]

    df.curso = curso
    df.orientacion = orientacion
    #=agregar_jornada_completa!(df) VER
    df.CC = [
    @sprintf("%d-%02d-%02d-%03d",
        Int(round(cue)),
        curso,
        ori,
        Int(round(alumnos))
    )
    for (cue, curso, ori, alumnos) in zip(
        df.CUE,
        df.curso,
        df.orientacion,
        df.Alumnos
    )
  ]=#

    #agregar_prioridad!(df, criterios)
    sort!(df, :prioridad)
#..............................................Devuelvo....................................
    push!(dfs,df)

  end
#.............................................Corroboro que coincidan las actividades......................................
  #corroborar(dfs, df_actividades) ## Falta afilar los controles para evitar errores <------------------------------------- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  return dfs
end
