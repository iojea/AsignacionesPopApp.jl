function columnas_necesarias(df, tipo)
    if tipo == "inscripciones"
      columnas =[
      "codigo unico de escuela (cue)",
      "fecha solicitada",
      "tipo de institucion educativa y orientacion",
      #"tipo de gestion de la institucion educativa",
      "ubicacion de la escuela",
      "cantidad de alumnos que asistiran",
      "curso que asistira",
      "porcentaje aproximado de estudiantes de familias de bajos recursos",
      #"dni del/la docente responsable de la visita"
    ]

      println("nombres del dataset $(length(names(df)))")
      columna_necesarias = Symbol.(columnas)
      faltantes = setdiff(columnas, names(df))

      if !isempty(faltantes)
          error("Faltan las columnas en el dataset de inscripciones: $faltantes")
      end


    elseif tipo == "actividades"
        columnas =[
          "label",
          "capacidad",
          "turno",
                                 "Horario de fin",
          "Horario de inicio",
          "tipo de actividad",
          "dia"
       ]

      columna_necesarias = Symbol.(columnas)
      faltantes = setdiff(columnas, names(df))

      if !isempty(faltantes)
          error("Faltan las columnas en el dataset de actividades: $faltantes")
      end
    end

  return 0
end

#------------------------------------------------------------------------------#
#=function tipos_de_datos(df,tipo)

end=#

#------------------------------------------------------------------------------#

function dias_de_actividades(df,actividades)

  dias_de_inscripciones = length(unique(df[:,"fecha solicitada"]))
  dias_de_actividades = length(unique(actividades[:,"dia"]))

  if dias_de_actividades < dias_de_inscripciones
    error("Hay $dias_de_inscripciones dias solicitados y $dias_de_actividades dias de actividades.")
  end
end

#------------------------------------------------------------------------------#

function tipos_de_actividades(actividades)

  tipos_permitidos = [
    "CHARLA",
    "ESTACIONES",
    "VISITA",
    "TALLER"
    ]

  datos = unique(actividades[:,"tipo de actividad"])
  erroneos = setdiff(tipos_permitidos, datos)

  if !isempty(erroneos)
      error("Tipos de actividades incompatibles: $erroneos")
  end
  return 0
end

#------------------------------------------------------------------------------#

function control_prefiltrado(inscripciones, actividades)

  #Corroborra que esten las columnas necesarias:
  columnas_necesarias(inscripciones, "inscripciones")
  columnas_necesarias(actividades,  "actividades")

  #Tipos de datos correctos en las columnas:
  #tipos_de_datos(inscripciones,"inscripciones")
  #tipos_de_datos(actividades, "actividades")

  #Coincidan los dias solicitados en las inscripciones con la cantidad de dias en act:
  dias_de_actividades(inscripciones, actividades)

  #Los tipos de actividades sean correctos:
  tipos_de_actividades(actividades)

  return 0
end