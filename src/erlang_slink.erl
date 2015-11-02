-module(erlang_slink).

-export([
    cluster/1,
    cluster/2,
    find/3,
    find/4,
    strip_dists/1,
    distance/2
]).

-compile({inline,[insert/3, lookup/2]}).

cluster(Data) ->
    cluster(Data, fun default_dist_fun/2).
cluster(Data, DistFun) ->
    DataT    = ets:new(dc_d, [set, private]),
    insert_data(Data, DataT),
    P        = ets:new(dc_p, [set, private]),
    insert(P, 1, 1),
    L        = ets:new(dc_l, [set, private]),
    insert(L, 1, infinity),
    M        = ets:new(dc_m, [set, private]),

    FoldFun = fun(N) ->
        step1(N, P, L, M),
        step2(N, P, L, M, DataT, DistFun),
        step3(N, P, L, M),
        step4(N, P, L, M)
    end,

    lists:foreach(FoldFun, lists:seq(1, length(Data) - 1)),
    Cluster = build_hierarchy(L, P, DataT),
    [ets:delete(T)||T<-[DataT, P, L, M]],
    Cluster.


insert_data(DataItems, Table) ->
    FoldFun = fun(Item, N) ->
            insert(Table, N, Item),
            N + 1
    end,
    lists:foldl(FoldFun, 1, DataItems).

step1(N, P, L, _M) ->
    insert(P, N+1, N+1),
    insert(L, N+1, infinity).


step2(N, _P, _L, M, Data, DistFun) ->
    FoldFun = fun(I) ->
        {VectorI,        _} = lookup(Data, I),
        {VectorNPlusOne, _} = lookup(Data, N + 1),
        Dist = DistFun(VectorI, VectorNPlusOne),
        insert(M, I, Dist)
    end,
    lists:foreach(FoldFun, lists:seq(1, N)).


step3(N, P, L, M) ->
    FoldFun = fun(I) ->

        PI = lookup(P, I),
        LI = lookup(L, I),
        MI = lookup(M, I),

        case LI >= MI of
            true ->
                insert(M, PI, min(lookup(M, PI), LI)),
                insert(L, I, lookup(M, I)),
                insert(P, I, N + 1);
            false ->
                insert(M, PI, min(lookup(M, PI), MI))
        end
    end,

    lists:foreach(FoldFun, lists:seq(1, N)).


step4(N, P, L, _M) ->
    FoldFun = fun(I) ->
        PI  = lookup(P, I),
        IL  = lookup(L, I),
        PIL = lookup(L, PI),
        case IL >= PIL of
            true  -> insert(P, I, N + 1);
            false -> noop
        end
    end,

    lists:foreach(FoldFun, lists:seq(1, N)).

build_hierarchy(LDict, PDict, DataT) ->
    DataList      = ets:tab2list(DataT),
    DataNoVectors = dict:from_list(
        lists:map(fun({I, {_V, Data}}) -> {I, Data} end, DataList)
    ),
    % we are iterating over the indices by distance
    DistIndexMap = lists:sort([{Dist, I} || {I, Dist} <- ets:tab2list(LDict)]),
    MapFun = fun({Distance, Index}, Clusters) ->
        case Distance =:= infinity of
            true  -> Clusters;
            false ->
                Item         = dict:fetch(Index,        Clusters),
                IndexSibling = lookup(PDict, Index),
                Sibling      = dict:fetch(IndexSibling, Clusters),
                % the new formed cluster has the ID of the sibling
                % which is the ID of the last Item in the cluster
                Clusters1  = dict:erase(Index, Clusters),
                NewCluster = {Distance, [Item, Sibling]},
                dict:store(IndexSibling, NewCluster, Clusters1)
        end
    end,
    ClusterAsDict = lists:foldl(MapFun, DataNoVectors, DistIndexMap),
    [{_, ClusterAsList}] = dict:to_list(ClusterAsDict),
    ClusterAsList.

default_dist_fun(VectorA, VectorB) ->
    distance(VectorA, VectorB).

% optimizing for 2D-vectors
distance([XA, YA], [XB, YB]) ->
    math:sqrt(math:pow((XA - XB), 2) + math:pow((YA - YB), 2));

% general case for n-dimensional vectors 
distance(A, B) ->
    DimPairs = lists:zip(A, B),
    SquareDiffs = lists:map(
        fun({CoordA, CoordB}) ->
            math:pow((CoordA - CoordB), 2)
        end,
        DimPairs
    ),
    math:sqrt(lists:sum(SquareDiffs)).

find(MatchFun, MaxClusterSize, Clusters) ->
    find(MatchFun, MaxClusterSize, infinity, Clusters).

find(_, _, _, []) ->
    not_found;

find(MatchFun, MaxClusterSize, DistanceCutoff, Clusters) ->
    {_, Found, RetCluster} = find_internal(MatchFun, MaxClusterSize, DistanceCutoff, Clusters),
    case Found of
        false -> not_found;
        _     -> RetCluster
    end.

find_internal(MatchFun, MaxClusterSize, DistanceCutoff, Cluster = {Distance, [SC1, SC2]}) ->
    {SC1Weight, SC1Found, SC1Cluster} = find_internal(MatchFun, MaxClusterSize, DistanceCutoff, SC1),
    {SC2Weight, SC2Found, SC2Cluster} = find_internal(MatchFun, MaxClusterSize, DistanceCutoff, SC2),
    Found = found(lists:sort([SC1Found, SC2Found])),
    Weight = SC1Weight + SC2Weight,
    case Found of
        false ->
            {Weight, Found, Cluster};
        complete ->
            case SC1Found of
                complete ->
                    {SC1Weight, complete, SC1Cluster};
                false ->
                    {SC2Weight, complete, SC2Cluster}
            end;
        incomplete ->
            case Weight =< MaxClusterSize andalso Distance < DistanceCutoff of
                true ->
                    {Weight, Found, Cluster};
                false ->
                    case SC1Found of
                        incomplete ->
                            {SC1Weight, complete, SC1Cluster};
                        false ->
                            {SC2Weight, complete, SC2Cluster}
                    end
            end
    end;

find_internal(MatchFun, _, _, Item) ->
    Found = case MatchFun(Item) of
        true  -> incomplete;
        false -> false
    end,
    {1, Found, Item}.

found([false, false])      -> false;
found([complete, false])   -> complete;
found([false, incomplete]) -> incomplete;
% this means that two items match the find criteria
% we also return incomplete so the first branch
% is picket in find_internal/4
found([incomplete, incomplete]) -> incomplete.

strip_dists({_Dist, [I1, I2]}) ->
    [strip_dists(I1), strip_dists(I2)];
strip_dists(I) ->
    I.

insert(Table, Key, Value) ->
    ets:insert(Table, {Key, Value}).

lookup(Table, Key) ->
    [{Key, Value}] = ets:lookup(Table, Key),
    Value.
