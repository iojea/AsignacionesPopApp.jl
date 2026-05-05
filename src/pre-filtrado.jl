function agregar_jornada_completa!(df)
    tm = uppercase.(strip.(coalesce.(df.TM, "")))
    tt = uppercase.(strip.(coalesce.(df.TT, "")))
    partido = uppercase.(strip.(coalesce.(df.Partido, "")))
    solicita_jc = (tm .== "SÍ") .& (tt .== "SÍ")
    habilitada_geo = (partido .!= "CIUDAD AUTÓNOMA DE BUENOS AIRES (CABA)") .&
                     (partido .!= "PARTIDOS DEL GRAN BUENOS AIRES - ZONA NORTE (PBA)")

    df[!, "Jornada Completa"] = ifelse.(
        solicita_jc .& habilitada_geo,
        "Si",
        ifelse.(
            solicita_jc,
            "No admitida",
            "No"
        )
    )

    return df
end
#-------------------------------------------------------------------------------

function separar_repetidos(df::DataFrame; dia_col="fecha solicitada")
    cue_limpio = coalesce.(df.CUE, "")
    doc_limpio = coalesce.(df.Docente, "")
    dia_limpio = coalesce.(df[!, dia_col], "")

    vistos_cue_dia = Set()
    vistos_doc_dia = Set()
##agregar lo del DNI y agregar lo de sacar el de menor prioridad
    keep = trues(nrow(df))

    for i in 1:nrow(df)
        repetido = false

        cue = cue_limpio[i]
        doc = doc_limpio[i]
        dia = dia_limpio[i]

        if cue != ""
            clave_cue = (cue, dia)
            if clave_cue in vistos_cue_dia
                repetido = true
            else
                push!(vistos_cue_dia, clave_cue)
            end
        end

        if doc != ""
            clave_doc = (doc, dia)
            if clave_doc in vistos_doc_dia
                repetido = true
            else
                push!(vistos_doc_dia, clave_doc)
            end
        end

        keep[i] = !repetido
    end

    df_filtrado = df[keep, :]
    repetidos_a_chequear = df[.!keep, :]

    return df_filtrado, repetidos_a_chequear
end

#-------------------------------------------------------------------------------

function primer_filtrado(ruta_crudo, ruta_cercanos)

  #=...........................................LEO LOS ARCHIVOS:..................................................
  df = CSV.read(
    ruta_crudo,
    DataFrame;
    delim='\t',
    quotechar='"',
    stripwhitespace=true,
    ignorerepeated=false, #cuando detecta multiples "\t\t" los considera como separados
    ignoreemptyrows=true,
    silencewarnings=true   # suprime warnings repetidos
)

  cercanos = CSV.read(
    ruta_cercanos,
    DataFrame;
    delim='\t',
    quotechar='"',
    stripwhitespace=true,
    ignorerepeated=false, #cuando detecta multiples "\t\t" los considera como separados
    ignoreemptyrows=true,
    silencewarnings=true   # suprime warnings repetidos )=#

  df = DataFrame(XLSX.readtable(ruta_crudo, 1))

  #........................................Chequeo que esten las columnas que necesita "Inscripciones.jl":...................................................
  columnas =[
    "nombre oficial y completo de la institucion educativa",
    "codigo unico de escuela (cue)",
    "tipo de institucion educativa y orientacion",
    "especifica la orientacion de tu institucion educativa",
    "tipo de gestion de la institucion educativa",
    "direccion de correo electronico donde va a recibir el resultado de la asignacion de vacantes",
    "ubicacion de la escuela",
    "barrio y comuna (caba) o localidad y partido (pba) de la institucion educativa",
    "cantidad de alumnos que asistiran",
    "curso que asistira",
    "porcentaje aproximado de estudiantes de familias de bajos recursos",
    "Turno/s solicitado/s [Turno mañana (9:00 a 12.30 hs.)]",
    "Turno/s solicitado/s [Turno tarde (12.30 a 16:00 hs.)]",
    "apellido y nombre del/la docente responsable de la visita",
  ]

  columna_necesarias = Symbol.(columnas)
  faltantes = setdiff(columnas, names(df))

  if !isempty(faltantes)
      error("Faltan columnas en el dataset: $faltantes")
  end

  rename!(df, :"apellido y nombre del/la docente responsable de la visita" => :Docente)
  rename!(df, Dict(
    "codigo unico de escuela (cue)" => "CUE",
    "ubicacion de la escuela" => "Partido",
    "Turno/s solicitado/s [Turno mañana (9:00 a 12.30 hs.)]" => "TM",
    "Turno/s solicitado/s [Turno tarde (12.30 a 16:00 hs.)]" => "TT"
  ))
  df.Docente = strip.(uppercase.(coalesce.(df.Docente, "")))


  #........................................Creo la columna Jornada Completa y marco los repetidos: ...................................................

  agregar_jornada_completa!(df)
  df, repetidos_a_chequear = separar_repetidos(df)
  df[!, "Estado"] = fill("Disponible", nrow(df))
  #CSV.write("filtrado.tsv", df; delim='\t', quotechar='"', missingstring="")
  #CSV.write("repetidos.tsv", repetidos_a_chequear; delim='\t', quotechar='"', missingstring="")


 XLSX.writetable(
    "resultado.xlsx",
    "Filtrados" => Tables.columntable(df),
    "Repetidos" => Tables.columntable(repetidos_a_chequear);
    overwrite=true
)
  return df#, repetidos_a_chequear #se podria sacar en al version final

end

