struct EdmondsKarpModificado <: GraphsFlows.AbstractFlowAlgorithm end

@traitfn function maximum_flow(
        flow_graph::::Graphs.IsDirected,       # the input graph
        source::Integer,                   # the source vertex
        target::Integer,                   # the target vertex
        capacity_matrix::AbstractMatrix,   # edge flow capacities
        df,
        combos_x_turno;
        algorithm::EdmondsKarpModificado,          # keyword argument for algorithm
    )
    combos = vcat(combos_x_turno...)
    residual_graph = GraphsFlows.residual(flow_graph)
    return edmonds_karp_impl2(residual_graph, source, target, capacity_matrix,df,combos)
end

#-------------------------------------------------------------------------------

function edmonds_karp_impl2 end
@traitfn function edmonds_karp_impl2(
        residual_graph::::Graphs.IsDirected,
        source::Integer,
        target::Integer,
        capacity_matrix::AbstractMatrix{T},
        df,
        combos
    ) where {T}

    n =  nrow(df)
    N = Graphs.nv(residual_graph)
    flow = zero(T)
    flow_matrix = spzeros(T, N, N) #CAMBIE zeros por spzeros

    P = fill(-1, N) #vector que guarda los Padres
    S = fill(-1, N) #vector que guarda los Sucesores

    while true

        camino_prohibido = spzeros(Bool, N, N)

        hay_camino_factible = false

        while true
            fill!(P, -1)
            fill!(S, -1)

            v, P, S, flag = fetch_path2!(
                residual_graph, source, target,
                flow_matrix, capacity_matrix,
                P, S,
                camino_prohibido
            )

            if flag != 0 # No hay más caminos residuales respetando  los caminos prohibidos
                break
            end

            # --- reconstruir path
            path = [Int(v)]
            sizehint!(path, N)

            u = v
            while u != source
                u = P[u]
                push!(path, u)
            end
            reverse!(path)

            u = v
            while u != target
                u = S[u]
                push!(path, Int(u))
            end

            # --- chequeo global de factibilidad real , doble chequeo
            ok, culpable = camino_factible(path, n, df, combos)

            if ok
                flow += augment_path2!(path, flow_matrix, capacity_matrix, n, df, combos)
                hay_camino_factible = true
                break
            else
                @assert culpable !== nothing
                cu, cv = culpable
                camino_prohibido[cu, cv] = true
            end
        end

        if !hay_camino_factible
            break
        end
    end

    return flow, flow_matrix
end

#-------------------------------------------------------------------------------------------------------

function fetch_path2! end
@traitfn function fetch_path2!(
    residual_graph::::Graphs.IsDirected,
    source::Integer,
    target::Integer,
    flow_matrix::AbstractMatrix,
    capacity_matrix::AbstractMatrix,
    P::Vector{Int},
    S::Vector{Int},
    camino_prohibido::AbstractMatrix{Bool}
)
    N = Graphs.nv(residual_graph)

    P[source] = -2
    S[target] = -2

    Q_f = Int[source]   # forward frontier
    sizehint!(Q_f, N)
    Q_r = Int[target]   # reverse frontier
    sizehint!(Q_r, N)

    while !isempty(Q_f) || !isempty(Q_r)

        if isempty(Q_r) || (!isempty(Q_f) && length(Q_f) <= length(Q_r))
            u = pop!(Q_f)

            for v in Graphs.outneighbors(residual_graph, u)
                # residual positivo, no prohibida y no visitado por forward
                if !camino_prohibido[u, v] &&
                   P[v] == -1 &&
                   capacity_matrix[u, v] - flow_matrix[u, v] > 0

                    P[v] = u

                    # si ya  fue alcanzado por reverse
                    if S[v] != -1
                        return v, P, S, 0
                    end

                    pushfirst!(Q_f, v)
                end
            end

        else
            v = pop!(Q_r)

            for u in Graphs.inneighbors(residual_graph, v)
                # en reverse marcamos con S[u], no con P[v]
                if !camino_prohibido[u, v] &&
                   S[u] == -1 &&
                   capacity_matrix[u, v] - flow_matrix[u, v] > 0

                    S[u] = v

                    # si ya fue alcanzado por forward
                    if P[u] != -1
                        return u, P, S, 0
                    end

                    pushfirst!(Q_r, u)
                end
            end
        end
    end

    return 0, P, S, 1   # si no hay camino
end

#-------------------------------------------------------------------------------------------------------

function augment_path2!(
    path::Vector{Int},
    flow_matrix::AbstractMatrix{T},
    capacity_matrix::AbstractMatrix,
    n::Int,
    df,
    combos
) where {T}

    augment = one(T)

    # actualizar flujo
    for i in 1:length(path)-1
        u = path[i]
        v = path[i+1]
        flow_matrix[u, v] += augment
        flow_matrix[v, u] -= augment
    end

    # actualizo las capacidades
    for i in 1:length(path)-1
        u = path[i]
        v = path[i+1]
        if es_curso(u, n) && es_combo(v, n, combos)
            agregar_curso_al_combo(u, v, n, df, combos)
        elseif es_combo(u, n, combos) && es_curso(v, n)
            quitar_curso_del_combo!(v, u, n, df, combos)
        end
    end

    return augment
end

#-------------------------------------------------------------------------------------------------------

function camino_factible(path::Vector{Int}, n::Int, df, combos) #CHAT
    # delta por actividad (
    delta = IdDict{Any, Int}()

    for i in 1:length(path)-1
        u = path[i]
        v = path[i+1]

        # forward: curso -> combo
        if es_curso(u, n) && es_combo(v, n, combos)
            alumnos = df[u-1, "Alumnos"]
            @assert alumnos !== missing "Alumnos missing para curso u=$u" #o que hacemos aca? es obligatorio en el formulario? espero q si ################################
            alumnos = Int(alumnos)

            combo_idx = v - n - 1
            @assert 1 <= combo_idx <= length(combos) "Índice de combo fuera de rango: v=$v n=$n => $combo_idx"
            combo = combos[combo_idx]
            for act in combo
                d = get(delta, act, 0) - alumnos
                if act.capacidad[] + d < 0
                    return false, (u, v)
                end
                delta[act] = d
            end

        # reverse: combo -> curso (libera)
        elseif es_combo(u, n, combos) && es_curso(v, n)
            alumnos = df[v-1, "Alumnos"]
            @assert alumnos !== missing "Alumnos missing para curso v=$v"
            alumnos = Int(alumnos)

            combo_idx = u - n - 1
            @assert 1 <= combo_idx <= length(combos) "Índice de combo fuera de rango: u=$u n=$n => $combo_idx"
            combo = combos[combo_idx]

            for act in combo
                d = get(delta, act, 0) + alumnos
                delta[act] = d
            end
        end
    end

    return true, nothing
end
