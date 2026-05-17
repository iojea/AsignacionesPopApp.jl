orden = Dict(
  "LUNES"=>1,"MARTES"=>2,"MIERCOLES"=>3,"JUEVES"=>4,"VIERNES"=>5,"SABADO"=>6,"DOMINGO"=>7, "MIÉRCOLES"=>3
)

#-------------------------------------------------------------------------------

function split_dfs_x_dia(df, dias)
    dfs_x_dia = []
    for dia in dias

        df_filtrado = df[coalesce.(df[!, "fecha solicitada"] .== dia, false), :]

        push!(dfs_x_dia, df_filtrado)
    end
    return dfs_x_dia
end

#-------------------------------------------------------------------------------

function Filtrar_inscripciones(ruta_inscripciones)

  #...........................................LEO LOS ARCHIVOS:..................................................

  df = DataFrame(XLSX.readtable(ruta_inscripciones, 1))

#........................................Los limpio y renombro:...................................................


  if "cantidad de alumnos que asistiran" in names(df) && !("Alumnos" in names(df))
    rename!(df,  "cantidad de alumnos que asistiran" => "Alumnos")
  end

  #.............................................spliteo el dataframe segun el dia de inscripcion...................................

  dias_aux = unique(collect(skipmissing(df[!, "fecha solicitada"])))
  dias = sort(dias_aux, by = s -> orden[uppercase(strip(first(split(s))))])
  dfs_x_dia = split_dfs_x_dia(df,dias)

#.............................................Corroboro que coincidan las actividades......................................
  return dfs_x_dia
end