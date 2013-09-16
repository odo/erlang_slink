# Erlang SLINK

Erlang SLINK is an implementatin of the hierarchical clustering algorithm as described in:


R. Sibson 1972: __"SLINK: An optimally efficient algorithm for the single-link cluster method"__  
The paper can be found at: www.cs.gsu.edu/~wkim/index_files/papers/sibson.pdf

The computational complexity is O(n<sup>2</sup>).

## Installation

```
git clone git@github.com:wooga/erlang_slink.git
cd erlang_slink
./rebar get-deps
./rebar compile
```

## Usage

### Clustering

The idea is to pass a list of items where each item has the form `{Vector, Data}`.
The Vector is arbitrary data which is used to determine the distance between two items. The item's data is arbitrary data to identify the item.

Given we want to cluster a bunch of people by age and weight we would do:

`erl -pz ebin deps/*/ebin`

```erlang
1> People = [
1>   {[1,  13], <<"Baby Bob">>},
1>   {[62, 82], <<"Aunt Mary">>},
1>   {[58, 95], <<"Uncle Robert">>},
1>   {[22, 62], <<"Witty Wendy">>}
1> ].
[{[1,13],<<"Baby Bob">>},
 {">R",<<"Aunt Mary">>},
 {":_",<<"Uncle Robert">>},
 {[22,62],<<"Witty Wendy">>}]
2> erlang_slink:cluster(People).
{53.31041174104736,
  [
    <<"Baby Bob">>,
    {44.721359549995796,
      [
        {13.601470508735444,
          [
            <<"Aunt Mary">>,
            <<"Uncle Robert">>
          ]
        },
        <<"Witty Wendy">>
      ]}
  ]
}
```

What we get is a cluster with nodes of the form `{Distance, [Element1, Element2]}` where the elements are either nodes or item data (the names in our case).
The distances is the distance to the nearest neighbour in the subclusters.

### Distance function

In this example above, we used the build-in distance function which calculates the euclidian distance. We can also pass our own distance function.
Say we want to group those who's weight is an even number: 

```erlang
3> Dist = fun([_, W1], [_, W2]) -> case W1 rem 2 == W2 rem 2 of true -> 0; false -> 1 end end.
#Fun<erl_eval.12.17052888>
4> erlang_slink:cluster(People, Dist).
{1,
  [
    {0,
      [
        <<"Baby Bob">>,
        <<"Uncle Robert">>
      ]
    },
    {0,
      [
        <<"Aunt Mary">>,
        <<"Witty Wendy">>
      ]
    }
  ]
}
```
So what we get is two groups, seperated by the distance 1 with two elements each seperated by distance 0.

### Extracting subclusters

You can extract a subcluster by starting from an item and then including more items as long as your constrains hold.
Constrains are the maximal distance (excluding that number) and the maximum cluster size (including that number)"

```erlang
5> C = erlang_slink:cluster(People).
6> erlang_slink:find(fun(<<"Aunt Mary">>) -> true; (_) -> false end, 4, 100, C).
{53.31041174104736,
 [<<"Baby Bob">>,
  {44.721359549995796,
   [{13.601470508735444,[<<"Aunt Mary">>,<<"Uncle Robert">>]},
    <<"Witty Wendy">>]}]}
7> erlang_slink:find(fun(<<"Aunt Mary">>) -> true; (_) -> false end, 4, 15, C).
{13.601470508735444,[<<"Aunt Mary">>,<<"Uncle Robert">>]}
8> erlang_slink:find(fun(<<"Aunt Mary">>) -> true; (_) -> false end, 3, 100, C).
{44.721359549995796,
 [{13.601470508735444,[<<"Aunt Mary">>,<<"Uncle Robert">>]},
  <<"Witty Wendy">>]}
```

### Stripping distances

Sometimes only the hierarchy of elements is important:

```erlang
9>  erlang_slink:strip_dists(C).
[
  <<"Baby Bob">>,
  [
    [
      <<"Aunt Mary">>,
      <<"Uncle Robert">>],
    <<"Witty Wendy">>
  ]
]
```

## Tests

`./bin/test`
