
function espera_aceptable(fin_A, ini_B, minutos_aceptables = 60) #conversar con popu el tiempo de espera, a priori 0
    res = false

    if fin_A <= ini_B && ini_B - fin_A < Minute(minutos_aceptables)
        res = true
    end
    
    return res
    
end


function combos_factibles(actividades)
    
    acts = sort(actividades, by = x -> x.inicio)
    
    combos = []

    function dfs(actual_combo, restantes)
        push!(combos, copy(actual_combo))
        for (i, act) in enumerate(restantes)
            if isempty(actual_combo) || espera_aceptable(last(actual_combo).fin,act.inicio)
                #podria agregar condiciones sobre mismas actividades pero nose si vale la pena. osea que no se generen las que despues termino filtrando.
                #-----------------------------------------------------------------------------
                dfs([actual_combo... , act], restantes[i+1:end])
            end
        end
    end

    dfs([], acts)

    return combos
end




function N_actividad(combo, T::Type) #esta bien pasado el tipo en "ordenar_combos"???????????????????????????????
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

function ordenar_combos(combos, min_act = 3, max_talleres = 1, max_visitas = 1, max_stands = 2, charlas_cons = 2,taller_y_visita = false)
    #deberia contar todas las actividades
    filter!(
        combo -> length(combo) >= min_act && #se fija que cada combo tenga min_act o mas
        N_actividad(combo, Taller) <= max_talleres && #no haya mas de max_talleres talleres ##### CHEQUEAR Q SE PASEN ASI LOS "TIPOS" <--------------------------------------
        N_actividad(combo, Visita) <= max_visitas && #no haya mas de max_visitas visitas 
        N_actividad(combo, Stand) <= max_stands && #no haya mas de max_stands stands
		TyV(combo) == taller_y_visita && #no haya taller y visita
		charlas_consecutivas(combo) < charlas_cons # no haya mas de "charlas_cons" charlas consecutivas
        , combos  
        )

end



##Nuevo codigo:

##Empiezo con la creacion de Combos de actividades factibles:

##Recibe un codigo de actividad y devuelve separada toda la informacion que contiene el codigo
function decode_codigo(code)
    s = String(code)                 # por si viene Symbol
    @assert length(s) >= 8 "Se esperaba al menos 8 dígitos, vino: $s"

    dia  = s[1:2]
    tipo = s[3:4]
    hora = parse(Int, s[5:6])
    min  = parse(Int, s[7:8])

    return (dia=dia, tipo=tipo, hora=hora, min=min)
end


###FALTA VER EL TEMA DE COMO MANEJAMOS LOS DIAS
##Función utilizada dentro de "construir_todas_las_actividades", dado un codigo e información sobre su duracion y capacidad genera el objeto act corrrespondiente.
function crear_actividad(codigo; capacidad=30,duracion = Minute(35))  #puedo usar una tabla de capacidades
    # Matchea: nombre, hora, minuto, día
  act = decode_codigo(codigo)
    ####codigo_valido() <-------------------------------------------------

  tipo_act =  cod2actividad["$(act[2])"]#me guardo cada cosa
""" hora = parse(Int, act[3])
    minuto = parse(Int, act[4])
    dia = cod2dia(act[1])"""

  #dia = fecha_base + Day(dia_offset)
  inicio = Time(act[3], act[4]) #cuando los minutos son "00" no aparecen, será un problema??? <----------------------------------------------
  fin = inicio + Minute(45)  # asumimos duración genérica
  duracion_stand = Time(act[3], act[4] + 10) # hay q elegir bien esto se podria ingresar una lista o cargarlo en el tsv de actividades

  if tipo_act == "CHARLA"
      return Charla(act[1], inicio, fin, capacidad,codigo)
  elseif tipo_act == "TALLER"
      return Taller(act[1], inicio, fin, capacidad,codigo)
  elseif tipo_act == "VISITA GUIADA"
      return Visita(act[1], inicio, fin, capacidad,codigo)
  elseif tipo_act == "STAND"
      return Stand(act[1], inicio, fin, capacidad, duracion_stand,codigo)
  else
      error("Tipo no reconocido: $tipo_act")
  end
end

##Corre la función anterior sobre todos los codigos leidos en el df original.
function construir_todas_las_actividades(actividades_x_dia::Vector{<:Vector})#, fecha_base::Date)
    return [
        [crear_actividad(codigo) for codigo in actividades]
        for actividades in actividades_x_dia
    ]
end

##Toma como parametro todas las actividades contenidas en el df original y aplica la funcion anterior para crear los objetos de act. y luego crea todos los combos de actividades
## posibles filtrando los no factibles.
function crear_combos(actividades_x_dia)

  act_x_dia_aux = construir_todas_las_actividades(actividades_x_dia)
  combos_x_dia = []

  for act_del_dia in act_x_dia_aux
    todas_las_combinaciones_dia = combos_factibles(act_del_dia) #armo todos los combos posibles
    combos_dia = ordenar_combos(todas_las_combinaciones_dia) #filtro los q no cumplen las reestricciones
    push!(combos_x_dia,combos_dia)
  end

  return combos_x_dia

end


##Recibe un codigo de actividad y devuelve separada toda la informacion que contiene el codigo
function decode_codigo(code)
    s = String(code)                 # por si viene Symbol
    @assert length(s) >= 8 "Se esperaba al menos 8 dígitos, vino: $s"

    dia  = s[1:2]
    tipo = s[3:4]
    hora = parse(Int, s[5:6])
    min  = parse(Int, s[7:8])

    return (dia=dia, tipo=tipo, hora=hora, min=min)
end

#----------------------------------------------------------------   

##Función utilizada dentro de "construir_todas_las_actividades", dado un codigo e información sobre su duracion y capacidad genera el objeto act corrrespondiente.
function crear_actividad(codigo; capacidad=30,duracion = Minute(35))  #puedo usar una tabla de capacidades
    # Matchea: nombre, hora, minuto, día
  act = decode_codigo(codigo)

    ####codigo_valido() <------------------------------------------------- faltaria hacer
  #capacidad = capacidad(codigo, df_act)
  #duracion = duracion(codigo, df_act)

  tipo_act =  cod2actividad["$(act[2])"]#me guardo cada cosa
""" hora = parse(Int, act[3])
    minuto = parse(Int, act[4])
    dia = cod2dia(act[1])"""

  #dia = fecha_base + Day(dia_offset)
  inicio = Time(act[3], act[4]) #cuando los minutos son "00" no aparecen, será un problema??? <----------------------------------------------
  fin = inicio + Minute(45)  # asumimos duración genérica
  duracion_stand = Time(act[3], act[4] + 10) # hay q elegir bien esto se podria ingresar una lista o cargarlo en el tsv de actividades

  if tipo_act == "CHARLA"
      return Charla(act[1], inicio, fin, 500, codigo) #inicio,fin,capcidad,codigo
  elseif tipo_act == "TALLER"
      return Taller(act[1], inicio, fin, 85 ,codigo)
  elseif tipo_act == "VISITA GUIADA"
      return Visita(act[1], inicio, fin, 50 ,codigo)
  elseif tipo_act == "STAND"
      return Stand(act[1], inicio, fin, 150 , duracion_stand,codigo)
  else
      error("Tipo no reconocido: $tipo_act")
  end
end

#----------------------------------------------------------------   

##Corre la función anterior sobre todos los codigos leidos en el df original.
function construir_todas_las_actividades(actividades_x_dia::Vector{<:Vector})#, fecha_base::Date)
    return [
        [crear_actividad(codigo) for codigo in actividades]
        for actividades in actividades_x_dia
    ]
end

#----------------------------------------------------------------   

##Toma como parametro todas las actividades contenidas en el df original y aplica la funcion anterior para crear los objetos de act. y luego crea todos los combos de actividades
## posibles filtrando los no factibles.
function crear_combos(actividades_x_dia)

  act_x_dia_aux = construir_todas_las_actividades(actividades_x_dia)
  combos_x_dia = []

  for act_del_dia in act_x_dia_aux
    todas_las_combinaciones_dia = combos_factibles(act_del_dia) #armo todos los combos posibles
    combos_dia = ordenar_combos(todas_las_combinaciones_dia) #filtro los q no cumplen las reestricciones
    push!(combos_x_dia,combos_dia)
  end

  return combos_x_dia

end

###pedir a populacion
"""
mas set de datos
capacidades para cada actividad
tiempos de espera
tiempos calculados para cada actividad
O(charlar que ponemos en el excel)

"""