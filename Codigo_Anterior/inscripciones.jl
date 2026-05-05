#=Se puede filtrar por año escolar, vulnerabilidad y orientación:
using CSV
import Pkg
Pkg.add("DataFrames")
using DataFrames

=#
#---------------------------FUNCIONES AUXILIARES--------------------------
function clasificar(df, criterios)
 resultado = [ [] for _ in criterios ]  # una lista por cada criterio

 for inscripcion in 1:nrow(df)
    for (i, criterio) in enumerate(criterios)
        if !ismissing(df[inscripcion,"curso"]) && criterio(df[inscripcion,:])
            push!(resultado[i], inscripcion)
            break  # para que no caiga en más de un criterio
        end
    end
 end
 return vcat(resultado...) #podriamos colapsarlo en una sola lista ahora (en lugar de una lista de listas). Seria mejor no?
end


function primer_numero(texto::AbstractString)
  m = match(r"\d+", texto)
  return isnothing(m) ? missing : parse(Int, m.match)
end

function split_df_x_dia(df, actividades_x_dias, fechas)
  dfs_x_dia = []
  for i in eachindex(actividades_x_dias)
      # Filtrar por fecha (manejando missing)
      df_filtrado = df[coalesce.(df[!, "Fecha solicitada"] .== fechas[i], false), :]

      # Seleccionar columnas: primeras 13 + actividades del día i
      df_dia = select(df_filtrado, 1:13, actividades_x_dias[i]...)

      push!(dfs_x_dia, df_dia)
  end
    return dfs_x_dia
  end

criterios = [ ### HAY UN PROBLEMA CON 7° AÑO DE LAS TECNICAS; NO ENTIENDO LA ELECCION. VER FORMULARIO >_____________________________________________________________________
e -> e.curso == 6 && e.vulnerabilidad > 49,
e -> e.orientacion == 2,
e -> e.orientacion == 1 && e.curso == 6, #&& 0 e.vulnerabilidad <= 49
e -> e.orientacion == 3 && e.curso == 6,####### En general en estas restricciones, 6to año o 5to año va a depender de la ubicacion de la escuela y la orientacion no???
e -> e.orientacion == 5 && e.curso == 6,####### Lo que quiero decir en realidad es "alumnos de ultimo año de secundario" no? podria hacer una funcion aux para identificar si estan en su último año
e -> e.orientacion == 4 && e.curso == 6,####### Eso me lleva a otra duda, que pasa con los colegios que inscribes a dos cursos en una misma inscripcion? no les permito hacer eso o como los trato?
#e -> e.UBA, #hay  otra forma?
e -> true#"el resto"
]

function corroborar(todos, control) #ESTOY CHEQUEANDO QUE HAYA LA CANTIDAD CORRECTA, NO EL HORARIO <----------------------------------------------------------------------
  dias = unique(control[:,"Dia"])
  discrepancias = ""

  for i in eachindex(dias)
    ctrl = control[control[!, "Dia"] .== dias[i], :]
    for act in unique(ctrl[:,1]) #CON ESTO ESTAMOS EXIGIENDO QUE SIEMPRE LA PRIMER COLUMNA SEA EL NOMBRE DE LA ACTIVIDAD
      act_dia = nrow(ctrl[ctrl[!, "Tipo de actividad"] .== act, :])
      if cuantasActPorDia(todos[i],act)[1] != act_dia
        discrepancias *= "Error en $act del dia $(dias[i])\n "
      end
    end
  end
  
  if discrepancias == ""
    discrepancias = "COINCIDEN TODAS LAS ACTIVIDADES."
  end
  
  return println(discrepancias)
end

############################ FUNCION PRINCIPAL #############################


function Filtrar_inscripciones(ruta_inscripciones, ruta_actividades, criterios)

  #...........................................LEO LOS ARCHIVOS:..................................................
  df_0 = CSV.read(
    ruta_inscripciones,
    DataFrame;
    delim='\t',
    quotechar='"',
    stripwhitespace=true,
    ignorerepeated=false, #cuando detecta multiples "\t\t" los considera como separados
    ignoreemptyrows=true,
    silencewarnings=true   # suprime warnings repetidos
)
  df_actividades = CSV.read(
    ruta_actividades,
    DataFrame;
    delim='\t',
    quotechar='"',
    stripwhitespace=true,
    ignorerepeated=false, #cuando detecta multiples "\t\t" los considera como separados
    ignoreemptyrows=true,
    silencewarnings=true   # suprime warnings repetidos
)

  #........................................Los limpio y renombro:...................................................
  df = df_0[:, vcat(3:7, 11, 14,15,17, 18, 20:82)]
  rename!(df, Dict(
    "Nombre OFICIAL y COMPLETO de la institución educativa" => "Nombre del colegio",
    "Código Único de Escuela (CUE)" => "CUE",
    "Tipo de escuela y orientación " => "Tipo de escuela",
    "Especifique su orientación" => "Orientacion",
    "Dirección de correo electrónico para recibir resultado de la asignación" => "Email",
    "Cantidad de alumnos que asistirán" => "Cantidad de alumnos",
    "Cursos que asistirán" => "Años", #Como hago cuando anotan a mas de un año <----------- si tiene un ultimo año ya esta.
    "Porcentaje aproximado de estudiantes de familias de bajos recursos  " => "vulnerabilidad",
    "Turno/s solicitado/s [Turno mañana (9:00 a 12.30 hs.)]" => "TM",
    "Turno/s solicitado/s [Turno tarde (12.30 a 16:00 hs.)]" => "TT", #Falta cambiarle el nombre a las actividades, y decidir a que lo cambiamos <---------------
))
  df_actividades  = df_actividades[:,["Tipo de actividad", "Hora de inicio", "Hora de finalizacion", "Capacidad", "Dia"]]


  #.................................Renombro las actividades para que esten uniformes #...............................................
  colnames = deepcopy(names(df))

  dias_totales = unique(df[:,"Fecha solicitada"]) |> length


  pattern_actividades = r"^\s*([\w\s]+?)\s*\[\s*(\d{1,2})\s*[:.]\s*(\d{2})\s*\]\s*(?:_(\d+))?\s*$"
  #diccionario para llevar la cuenta de qué día corresponde a cada actividad
  dias = Dict{String, Int}()

  # Vector para guardar los nombres nuevos
  newnames = []
  actividades_x_dias = [[] for _ in 1:(dias_totales - 1) ]

  for col in colnames
      m = match(pattern_actividades, col)
      if m !== nothing
          actividad = strip(m.captures[1])          # ej: "CHARLAS"
          hora = parse(Int, m.captures[2])          # ej: 9
          minuto = parse(Int, m.captures[3])        # ej: 30

          dia = m.captures[4] === nothing ? 0 : parse(Int, m.captures[4])  # si aparece _1 o _2

          #Si la actividad nunca apareció, la inicializo
          if !haskey(dias, actividad)
              dias[actividad] = dia
          else
              # Si el día actual es mayor al registrado, lo actualizo
              if dia > dias[actividad]
                  dias[actividad] = dia
              end
          end

          # Formato de hora hh:mm con padding
          hora_str = lpad(string(hora), 2, '0')
          minuto_str = lpad(string(minuto), 2, '0')


          # Armo el string de día
          dia_str = dias[actividad] == 0 ? "0" : "$(dias[actividad])"
          push!(actividades_x_dias[parse(Int, dia_str)+1],"$(actividad) [$hora_str:$minuto_str]$(dia_str)")




          newname = "$(actividad) [$hora_str:$minuto_str]$(dia_str)"
          push!(newnames, newname)
          #println("Columna: $col  →  Nuevo nombre: $newname") #opcional

      else
          # Si no matchea el patrón, dejo el nombre original
          push!(newnames, col)
      end
  end

  # Asigno los nombres nuevos al DataFrame
  rename!(df, Symbol.(colnames) .=> Symbol.(newnames))

  #.............................................spliteo el dataframe segun el dia de inscripcion...................................

  fechas = ["Martes 22/4", "Miércoles 23/4", "Jueves 24/4"] #tengo que arreglar esto <------------------------- ###############################################
  #Podria arreglarlo con un unique(df_actividades[:,"Dia"]) pero las columnas se escriben con minuscula.

  dfs_x_dia = split_df_x_dia(df, actividades_x_dias,fechas)

  #..............................................Ordeno las inscripciones en orden de prioridad......................................
  dfs = []
  for df in dfs_x_dia
    # Add curso and orientacion columns to the split dataframe
    curso = [!ismissing(x) ? primer_numero(x) : missing for x in df.Años]
    orientacion = [!ismissing(x) ? primer_numero(x) : missing for x in df[:,"Tipo de escuela"]]

    df.curso = curso
    df.orientacion = orientacion
    push!(dfs,df[clasificar(df,criterios),:])
  end

#.............................................Corroboro que coincidan las actividades......................................
  corroborar(dfs, df_actividades)
  return dfs
end


########################LO DE ARRIBA ES VIEJO, LO DE ABAJO ES NUEVO##########################

##Diccionarios para crear los codigos de las actividades:
nombre2clave = Dict(
    "CHARLAS" => "01",
    "VISITA" => "02",
    "VISITA GUIADA" => "02",
    "VISITAS GUIADAS" => "02",
    "TALLERES" => "03",
    "ESTACIONES INTERACTIVAS"  => "04",
    "Lunes"  => "01",
    "Martes" => "02",
    "Miércoles" => "03",
    "Jueves" => "04",
    "Viernes" => "05",
    "Sabado" => "06",
    "Domingo" => "07",
)

cod2dia = Dict(
    "01" => "Lunes",
    "02" => "Martes",
    "03" => "Miércoles",
    "04" => "Jueves",
    "05" => "Viernes",
    "06" => "Sabado",
    "07" => "Domingo",
)

cod2actividad = Dict(
    "01" => "CHARLA",
    "02" => "VISITA GUIADA",
    "03" => "TALLER",
    "04" => "STAND",
)

orden = Dict(
    "Lunes" => 1, "Martes" => 2, "Miércoles" => 3, "Miercoles" => 3,
    "Jueves" => 4, "Viernes" => 5, "Sábado" => 6, "Sabado" => 6,
    "Domingo" => 7
)


##Lectura de datos:

#---------------------------FUNCIONES AUXILIARES--------------------------
##Para hacer chequeos: (Actualmente en desuso dentro de "corroborar". )
function cuantasActPorDia(df, act)
    colnames = names(df)
    pattern_actividades = r"^\s*([\w\s]+?)\s*\[\s*(\d{1,2})\s*[:.]\s*(\d{2})\s*\]\s*?\d+?\s*$"
    Act_por_dia = []
    contador = 0
    for col in colnames
        m = match(pattern_actividades, col)

        if m !== nothing
            if act == strip(m.captures[1])
                contador += 1
            else
                if contador != 0
                    push!(Act_por_dia, contador)
                end
                contador = 0
            end

        else
          if contador != 0
            push!(Act_por_dia, contador)
            contador = 0
          end
        end
    end
    return Act_por_dia
end

##Utilizada para filtrar la informacion del año escolar  y orientación de las inscripciones:
function primer_numero(texto::AbstractString)
  m = match(r"\d+", texto)
  return isnothing(m) ? missing : parse(Int, m.match)
end

##Utilizada para separar el dataset general en uno filtrado por fecha solicitada. (se podria sacar "dias" como variable y realizar el armado dentro de la misma función.)
function split_df_x_dia(df, dias)
    dfs_x_dia = []
    for dia in dias
        # filtrar filas exactas (tu dias coincide con "Fecha solicitada")
        df_filtrado = df[coalesce.(df[!, "Fecha solicitada"] .== dia, false), :]

        dia = first(split(dia))
        codigo_dia = nombre2clave[dia]

        df_dia = select(df_filtrado, 1:13, Regex("^" * codigo_dia))

        push!(dfs_x_dia, df_dia)
    end
    return dfs_x_dia
end


criterios = [ ### HAY UN PROBLEMA CON 7° AÑO DE LAS TECNICAS; NO ENTIENDO LA ELECCION. VER FORMULARIO >_____________________________________________________________________
e -> e.curso == 6 && e.vulnerabilidad > 49,
e -> e.orientacion == 2,
e -> e.orientacion == 1 && e.curso == 6, #&& 0 e.vulnerabilidad <= 49
e -> e.orientacion == 3 && e.curso == 6,####### En general en estas restricciones, 6to año o 5to año va a depender de la ubicacion de la escuela y la orientacion no???
e -> e.orientacion == 5 && e.curso == 6,####### Lo que quiero decir en realidad es "alumnos de ultimo año de secundario" no? podria hacer una funcion aux para identificar si estan en su último año
e -> e.orientacion == 4 && e.curso == 6,####### Eso me lleva a otra duda, que pasa con los colegios que inscribes a dos cursos en una misma inscripcion? no les permito hacer eso o como los trato?
#e -> e.UBA, #hay  otra forma?
e -> true#"el resto"
]

function corroborar(todos, control) #ESTOY CHEQUEANDO QUE HAYA LA CANTIDAD CORRECTA, NO EL HORARIO <----------------------------------------------------------------------
  dias = unique(control[:,"Dia"])
  discrepancias = ""

  for i in eachindex(dias)
    ctrl = control[control[!, "Dia"] .== dias[i], :]
    for act in unique(ctrl[:,1]) #CON ESTO ESTAMOS EXIGIENDO QUE SIEMPRE LA PRIMER COLUMNA SEA EL NOMBRE DE LA ACTIVIDAD
      act_dia = nrow(ctrl[ctrl[!, "Tipo de actividad"] .== act, :])
      if cuantasActPorDia(todos[i],act)[1] != act_dia
        discrepancias *= "Error en $act del dia $(dias[i])\n "
      end
    end
  end

  if discrepancias == ""
    discrepancias = "COINCIDEN TODAS LAS ACTIVIDADES."
  end

  return println(discrepancias)
end

############################ FUNCION PRINCIPAL #############################


function Filtrar_inscripciones(ruta_inscripciones, ruta_actividades, criterios)

  #...........................................LEO LOS ARCHIVOS:..................................................
  df_0 = CSV.read(
    ruta_inscripciones,
    DataFrame;
    delim='\t',
    quotechar='"',
    stripwhitespace=true,
    ignorerepeated=false, #cuando detecta multiples "\t\t" los considera como separados
    ignoreemptyrows=true,
    silencewarnings=true   # suprime warnings repetidos
)
  """ ### LA IDEA ES UTILIZAR ESTE ARCHIVO COMPLEMENTARIO PARA HACER CHEQUEOS CRUZADOS DE LAS ACTIVIDADES Y HORARIOS
  df_actividades = CSV.read(
    ruta_actividades,
    DataFrame;
    delim='\t',
    quotechar='"',
    stripwhitespace=true,
    ignorerepeated=false, #cuando detecta multiples "\t\t" los considera como separados
    ignoreemptyrows=true,
    silencewarnings=true   # suprime warnings repetidos
)
"""
  #........................................Los limpio y renombro:...................................................
  df = df_0[:, vcat(3:7, 11, 14,15,17, 18, 20:82)]
  rename!(df, Dict(
    "Nombre OFICIAL y COMPLETO de la institución educativa" => "Nombre del colegio",
    "Código Único de Escuela (CUE)" => "CUE",
    "Tipo de escuela y orientación " => "Tipo de escuela",
    "Especifique su orientación" => "Orientacion",
    "Dirección de correo electrónico para recibir resultado de la asignación" => "Email",
    "Cantidad de alumnos que asistirán" => "Cantidad de alumnos",
    "Cursos que asistirán" => "Años", #Como hago cuando anotan a mas de un año <----------- si tiene un ultimo año ya esta.
    "Porcentaje aproximado de estudiantes de familias de bajos recursos  " => "vulnerabilidad",
    "Turno/s solicitado/s [Turno mañana (9:00 a 12.30 hs.)]" => "TM",
    "Turno/s solicitado/s [Turno tarde (12.30 a 16:00 hs.)]" => "TT", #Falta cambiarle el nombre a las actividades, y decidir a que lo cambiamos <---------------
))
  #df_actividades  = df_actividades[:,["Tipo de actividad", "Hora de inicio", "Hora de finalizacion", "Capacidad", "Dia"]]


  #.................................Renombro las actividades para que esten uniformes #...............................................
  dias_aux = unique(collect(skipmissing(df[!, "Fecha solicitada"])))
  dias = sort(dias_aux, by = s -> orden[strip(first(split(s)))])
  puntero_dia = 1

  colnames = deepcopy(names(df))

  pattern_actividades = r"^\s*(.*?)\s*\[\s*(\d{1,2})\s*[:.]\s*(\d{2})\s*\]\s*(?:_(\d+))?\s*$"
  pattern_separador = r"^\s*Exprese\b"

  newnames = String[]
  actividades = [Any[] for _ in 1:length(dias)]

  for col in colnames
      m = match(pattern_actividades, String(col))
      sep = match(pattern_separador, String(col))

      if m !== nothing
          actividad = strip(m.captures[1])
          hora = parse(Int, m.captures[2])
          minuto = parse(Int, m.captures[3])

          hora_str = lpad(string(hora), 2, '0')
          min_str  = lpad(string(minuto), 2, '0')

          dia_str = first(split(dias[puntero_dia]))  # "Martes"
          codigo = nombre2clave[dia_str] * nombre2clave[actividad] * hora_str * min_str

          push!(newnames, codigo)
          push!(actividades[puntero_dia],codigo)
          println("Columna: $col  →  Nuevo nombre: $codigo")

      elseif sep !== nothing
          puntero_dia += 1
          push!(newnames, String(col))  # para mantener alineación de tamaños

      else
          push!(newnames, String(col))
      end
  end

  rename!(df, Symbol.(colnames) .=> Symbol.(newnames))


  #.............................................spliteo el dataframe segun el dia de inscripcion...................................

  ##fechas = ["Martes 22/4", "Miércoles 23/4", "Jueves 24/4"] #tengo que arreglar esto <------------------------- ###############################################
  #Podria arreglarlo con un unique(df_actividades[:,"Dia"]) pero las columnas se escriben con minuscula.
  ###ARREGLADO###
  dfs_x_dia = split_df_x_dia(df,dias)

  #..............................................Ordeno las inscripciones en orden de prioridad......................................
  dfs = []
  for df in dfs_x_dia

    curso = [!ismissing(x) ? primer_numero(x) : missing for x in df.Años]
    orientacion = [!ismissing(x) ? primer_numero(x) : missing for x in df[:,"Tipo de escuela"]]

    df.curso = curso
    df.orientacion = orientacion
    push!(dfs,df[clasificar(df,criterios),:])

  end

#.............................................Corroboro que coincidan las actividades......................................
  #corroborar(dfs, df_actividades) ## Falta afilar los controles para evitar errores <-------------------------------------
  return dfs, actividades
end



