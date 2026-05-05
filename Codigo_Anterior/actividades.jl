#que concideramos aceptable de 
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