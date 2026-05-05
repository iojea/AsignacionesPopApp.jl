abstract type ActividadGeneral end

struct Taller{I<:Integer} <: ActividadGeneral
    dia::AbstractString
    inicio::Time
    fin::Time
    capacidad::Base.RefValue{I}
    turno::AbstractString
    label::AbstractString
    id::I
end

struct Estaciones{I<:Integer} <: ActividadGeneral
    dia::AbstractString
    inicio::Time
    fin::Time
    capacidad::Base.RefValue{I}
    turno::AbstractString
    label::AbstractString
    id::I
end

struct Charla{I<:Integer} <: ActividadGeneral
    dia::AbstractString
    inicio::Time
    fin::Time
    capacidad::Base.RefValue{I}
    turno::AbstractString
    label::AbstractString
    id::I
end

struct Visita{I<:Integer} <: ActividadGeneral
    dia::AbstractString
    inicio::Time
    fin::Time
    capacidad::Base.RefValue{I}
    turno::AbstractString
    label::AbstractString
    id::I
end

struct Almuerzo{I<:Integer} <: ActividadGeneral
    dia::AbstractString
    capacidad::Base.RefValue{I}
    label::AbstractString
end