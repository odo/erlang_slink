-module(erlang_slink_test).

-compile(export_all).

% Include etest's assertion macros.
-include_lib("etest/include/etest.hrl").

before_suite() ->
    application:start(mrs).

after_suite() ->
    application:stop(mrs).

test_cluster1() ->
    Data = [{[56], fiftysix},{[21], twentyone}, {[46], fortysix},
            {[43], fortythree}, {[0], zero}, {[57], fiftyseven}, {[48], fortyeight}],


    Cluster = mrs_cluster:cluster(Data),
    Expected = {22.0,
                         [{21.0,[twentyone,zero]},
                          {8.0,
                           [{1.0,[fiftysix,fiftyseven]},
                            {3.0,
                             [fortythree,{2.0,[fortysix,fortyeight]}]}]}]},
    ?assert_equal(Expected, Cluster).

test_cluster2() ->
    Items = [
        {[2],  0},
        {[4],  1},
        {[7],  2},
        {[17], 3},
        {[18], 4}
    ],
    Cluster = mrs_cluster:cluster(Items),
    Expected = [[[0,1],2],[3,4]],
    ?assert_equal(Expected, mrs_cluster:strip_dists(Cluster)),
    MatchFun = fun(Data) -> Data =:= 1 end,
    ?assert_equal([[0, 1], 2], mrs_cluster:strip_dists(mrs_cluster:find(MatchFun, 4, infinity, Cluster))).

test_find_in_equals() ->
    Items = [
        {[2], 0},
        {[3], 1},
        {[7], 2},
        {[8], 3},
        {[100], 4}
    ],
    Cluster = mrs_cluster:cluster(Items),
    MatchFun = fun(Data) -> Data =:= 1 end,
    ?assert_equal(
        [0, 1],
        mrs_cluster:strip_dists(mrs_cluster:find(MatchFun, 3, infinity, Cluster))
    ),
    ?assert_equal(
        [[0, 1], [2, 3]],
        mrs_cluster:strip_dists(mrs_cluster:find(MatchFun, 4, infinity, Cluster))
    ),
    ?assert_equal(
        [[[0, 1], [2, 3]], 4],
        mrs_cluster:strip_dists(mrs_cluster:find(MatchFun, 5, infinity, Cluster))
    ).


test_find() ->
    Items = [
        {[2],  0},
        {[4],  1},
        {[7],  2},
        {[17], 3},
        {[18], 4}
    ],
    Cluster = mrs_cluster:cluster(Items),
    Expected = {10.0,
                    [{3.0,
                      [{2.0,
                        [0,1]}
                       ,2]},
                     {1.0,
                      [3,4]}]},
    ?assert_equal(Expected, Cluster),
    MatchFun = fun(Data) -> Data =:= 1 end,
    ?assert_equal(
        {3.0,[{2.0,[0,1]},2]},
        mrs_cluster:find(MatchFun, 4, infinity, Cluster)),
    ?assert_equal(
        {2.0,[0,1]},
        mrs_cluster:find(MatchFun, 4, 2.5, Cluster)).

test_find_ambigous() ->
    Items = [
        {[2],  same},
        {[4],  1},
        {[7],  same},
        {[17], 3},
        {[18], 4}
    ],
    Cluster = mrs_cluster:cluster(Items),
    Expected = {10.0,
                    [{3.0,
                      [{2.0,
                        [same,1]}
                       ,same]},
                     {1.0,
                      [3,4]}]},
    ?assert_equal(Expected, Cluster),
    MatchFun = fun(Data) -> Data =:= same end,
    ?assert_equal(
        {3.0,[{2.0,[same,1]},same]},
        mrs_cluster:find(MatchFun, 4, infinity, Cluster)),
    ?assert_equal(
        {2.0,[same,1]},
        mrs_cluster:find(MatchFun, 4, 2.5, Cluster)).

test_cluster_deluxe() ->
    Items = [
        {[0],  item0},
        {[1],  item1},
        {[3],  item2},
        {[6], item3},
        {[7], item4},
        {[20], item5},
        {[21], item6},
        {[25], item7},
        {[26], item8},
        {[28], item9}
    ],
    Cluster = mrs_cluster:cluster(Items),
    Expected =
        {13.0, [
            {3.0, [
                {2.0, [
                    {1.0,[
                        item0,item1
                    ]},
                    item2
                ]},
                {1.0, [
                    item3,item4
                ]}
            ]},
            {4.0, [
                {1.0, [
                    item5,item6
                ]},
                {2.0, [
                    {1.0,[
                        item7,item8
                    ]},
                    item9
                ]}
            ]}
        ]},
    ?assert_equal(Expected, Cluster),

    AssertFindCluster = fun(Expectation, Item, MaxClusterSize, DistanceCutoff) ->
        MatchFun = fun(Data) -> Data =:= Item end,
        Res = mrs_cluster:find(MatchFun, MaxClusterSize, DistanceCutoff, Cluster),
        case Res of
            not_found ->
                ?assert_equal(Expectation, Res);
            _ ->
                ?assert_equal(
                    Expectation,
                    mrs_cluster:strip_dists(Res))
        end
    end,

    % test with unlimited size and distance
    AssertFindCluster(mrs_cluster:strip_dists(Cluster),
                      item0, infinity, infinity),
    % test with never-matching MatchFun
    AssertFindCluster(not_found,
                      not_here, infinity, infinity),

    % test cluster size
    AssertFindCluster([[item0, item1], item2],
                      item0, 4, infinity),
    AssertFindCluster([[item0, item1], item2],
                      item1, 4, infinity),
    AssertFindCluster([[item0, item1], item2],
                      item2, 4, infinity),
    AssertFindCluster([item3, item4],
                      item3, 4, infinity),
    AssertFindCluster([item3, item4],
                      item4, 4, infinity),
    AssertFindCluster([[[item0,item1],item2],[item3,item4]],
                      item4, 5, infinity),
    AssertFindCluster([item5, item6],
                      item5, 4, infinity),
    AssertFindCluster([item5, item6],
                      item6, 4, infinity),
    AssertFindCluster([item5, item6],
                      item6, 3, infinity),
    AssertFindCluster([item5, item6],
                      item6, 2, infinity),
    AssertFindCluster([[item7,item8],item9],
                      item7, 4, infinity),
    AssertFindCluster([[item7,item8],item9],
                      item8, 4, infinity),
    AssertFindCluster([[item7,item8],item9],
                      item9, 4, infinity),

    % test distance
    AssertFindCluster([item0, item1],
                      item0, infinity, 1.1),

    AssertFindCluster([[[item0,item1],item2],[item3,item4]],
                      item0, infinity, 3.1).

test_custom_dist_fun() ->
    Items = [
        {[1, 0],  item0},
        {[2, 1],  item1},
        {[3, 3],  item2},
        {[1, 6],  item3},
        {[2, 7],  item4},
        {[3, 20], item5},
        {[1, 21], item6},
        {[2, 25], item7},
        {[3, 26], item8},
        {[1, 28], item9}
    ],
    % we are using a function which puts distante
    % items together
    DistFun = fun([TypeA, CoordA], [TypeB, CoordB]) ->
        DType   = mrs_cluster:distance([TypeA],  [TypeB]),
        DCoords = mrs_cluster:distance([CoordA], [CoordB]),
        DCoords + DType * 100
    end,
    Cluster = mrs_cluster:cluster(Items, DistFun),
    Expected = [[item2,[item5,item8]],
                         [[[item1,item4],item7],
                          [[item0,item3],[item6,item9]]]],
    ?assert_equal(Expected, mrs_cluster:strip_dists(Cluster)).

assert_distance(D, A, B) ->
    ?assert_equal(D, mrs_cluster:distance(A, B)).

test_distance() ->
    assert_distance(0.0, [0.0], [0.0]),
    assert_distance(0.0, [0.0, 0.0], [0.0, 0.0]),
    assert_distance(48.17488972483487, [6.0, 51.0, 3.0], [1.9, 99, 2.9]),
    assert_distance(3.6391533355988175, [0.693, -1.501, -0.201], [-1.222, 1.573, -0.557]),
    assert_distance(47.01063709417264, [1, 13], [2, 60]).
