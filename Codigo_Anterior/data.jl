abstract type ActividadGeneral end
#Modificar estructuras a no mutables
mutable struct Taller{I<:Integer} <: ActividadGeneral
    dia::String ###Date
    inicio::Time
    fin::Time
    capacidad::I
    codigo::String
end

mutable struct Stand{I<:Integer} <: ActividadGeneral
    dia::String ###Date
    inicio::Time
    fin::Time
    capacidad::I
    duracion::Time
    codigo::String
end

mutable struct Charla{I<:Integer} <: ActividadGeneral
    dia::String ###Date
    inicio::Time
    fin::Time
    capacidad::I
    codigo::String
end

mutable struct Visita{I<:Integer} <: ActividadGeneral
    dia::String ###Date
    inicio::Time
    fin::Time
    capacidad::I
    codigo::String
end

duracion(a::ActividadGeneral) = Hour(a.fin - a.inicio)
duracion(a::Stand) = a.duracion


#=
struct Restricciones #NO ENTIENDO ESTO <--------------------------------------------------------------
    charla::Bool
    taller::Bool
end



struct Escuela{S<:AbstractString} #que seria N y S????  <--------------------------------------------------------
    nombre::S
    orientacion::Integer #numeramos las especialidades se las mas relevantes a las menos
    uba::Bool #True si es un colegio "UBA", podriamos ponerlo como una "orientacion" especial.
    curso::Integer #año escolar que inscribe
    publica::Bool # True si es publica, False si es privada
    alumnos::Integer #numero de alumnos q inscribe
    #accesoCs::Integer # nos interesa? acceso a ciencias exactas. no parece utilizarce para nada en el filtrado   <----------------------------
    vulnerabilidad::Integer #necesario para los filtros
    dias::Integer #es solo un dia por inscripcion no? <--------------------------------
    inicio::Time
    fin::Time 
    restricciones::Restricciones 
end

function Escuela(...)
 orientacion,curso,alumnos = promote(orientacion,curso,alumnos)
 Escuela(....)
end


nombre(e::Escuela) = e.nombre
inicio(e::Escuela) = e.inicio
fin(e::Escuela) = e.fin
duracion(e::Escuela) = Hour(e.fin - e.inicio)
charla(e::Escuela) = e.restricciones.charla
taller(e::Escuela) = e.restricciones.taller

Escuela("Normal 2",2,true,5,true,30,2,1,Time(9),Time(13),Restricciones(true,false))
=#