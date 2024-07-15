module [
    Graph,
    fromList,
    fromDict,
    aStar,
    aStar2,
]

## Graph type representing a graph as a dictionary of adjacency lists,
## where each key is a vertex and each value is a list of its adjacent vertices.
Graph a := Dict a (List a) where a implements Eq

Graph2 a : a -> Result (List a) [NotFound] where a implements Eq

fromList2 : List (a, List a) -> Graph2 a
fromList2 = \adjacencyList ->
    \a ->
        List.findFirst adjacencyList \(b, _) -> b == a
        |> Result.map \tuple -> tuple.1
        |> Result.mapErr \_ -> NotFound

## Create a Graph from an adjacency list.
fromList : List (a, List a) -> Graph a
fromList = \adjacencyList ->
    emptyDict = Dict.withCapacity (List.len adjacencyList)

    update = \dict, (vertex, edges) ->
        Dict.insert dict vertex edges

    List.walk adjacencyList emptyDict update
    |> @Graph

## Create a Graph from an adjacency list.
fromDict : Dict a (List a) -> Graph a
fromDict = @Graph

Estimator a : a -> I32
Compare a : a, a -> [LT, GT, EQ]
constZero : Estimator a
constZero = \_ -> 0
# prioritizeStack : Compare (a, I32)
# prioritizeStack = \a, b ->
#     aa = a.1 #estimator a.1 |> Num.add a.1
#     bb = b.1 #estimator b.1 |> Num.add b.1
#     if aa < bb then
#         LT
#     else if aa > bb then
#         GT
#     else
#         EQ
priorityWithEstimate : Estimator a -> Compare (a, I32)
priorityWithEstimate = \estimator -> \a, b ->
        aa = estimator a.0 |> Num.add a.1
        bb = estimator b.0 |> Num.add b.1
        if aa < bb then
            LT
        else if aa > bb then
            GT
        else
            EQ

## priorityWithEstimate should return natural order when cost is always 0
expect
    sortFn = priorityWithEstimate constZero
    list = [("a", 2), ("b", 0), ("c", 1)]
    actual = List.sortWith list sortFn
    expected = [("b", 0), ("c", 1), ("a", 2)]
    actual == expected

## priorityWithEstimate should compare current + estimated value
## when sorting
expect
    sortFn = priorityWithEstimate \s -> if Str.startsWith s "b" then 5 else 0
    list = [("a", 2), ("b", 0), ("c", 1)]
    actual = List.sortWith list sortFn
    expected = [("c", 1), ("a", 2), ("b", 0)]
    actual == expected

CostDict a : List (a, I32)
findCost : a, CostDict a -> Result (a, I32) [NotFound] where a implements Hash & Eq
findCost = \a, costs ->
    List.findFirst costs \(n, _) -> n == a
    |> Result.map .1
    |> Result.map \cost -> (a, cost)
    |> Result.mapErr \_ -> NotFound

addCosts = \nodes, currentCost, costs ->
    List.walk nodes costs \accum, discovered ->
        insertCost discovered (currentCost + 1) accum

insertCost = \a, cost, costs ->
    List.append costs (a, cost)

makeCosts : a -> CostDict a where a implements Hash & Eq
makeCosts = \a -> [(a, 0)]
# Parents a : List (parent, child)
Parents a : List (a, a) where a implements Hash & Eq
findParentOf : a, Parents a -> Result a [NotFound] where a implements Eq & Hash
findParentOf = \a, parents ->
    # Dict.get parents a
    List.findFirst parents \(_, child) -> child == a
    |> Result.map .0
    |> Result.mapErr \_ -> NotFound

addParents : a, List a, Parents a -> Parents a
addParents = \current, nodes, parents ->
    List.walk nodes parents \accum, discovered ->
        insertParent discovered current accum

insertParent = \child, parent, parents ->
    List.append parents (parent, child)

makeEmptyParents : _ -> Parents a where a implements Hash & Inspect & Eq
makeEmptyParents = \_ -> []

## Takes our Parents and a target node and returns a list of target nodes
## in order
makePathTo : a, Parents a -> List a
makePathTo = \v, paths ->
    iter = \p, ps ->
        findParentOf p paths
        |> Result.map \a -> iter a (List.prepend ps a)
        |> Result.withDefault ps
    iter v [v]

## Perform a breadth-first search with a fixed cost of 1 for each step
## and an `Estimator` function to determine priority
## - `isTarget` : A function that returns true if a vertex is the target.
## - `root`     : The starting vertex for the search.
## - `graph`    : The graph to perform the search on.
aStar : (a -> Bool),
    Estimator a,
    a,
    Graph2 a
    ->
    Result (a, List a) [NotFound] where a implements Hash & Eq & Inspect
aStar = \isTarget, estimator, root, graph ->
    initialCosts = makeCosts root
    initialParents = makeEmptyParents {}
    aStarHelper isTarget estimator [root] initialCosts initialParents graph
    |> Result.map \(t, paths) -> (t, makePathTo t paths)

aStar2 : { isTarget : a -> Bool, root : a, graph : Graph2 a, estimator : Estimator a }
    ->
    Result (a, List a) [NotFound] where a implements Hash & Eq & Inspect
aStar2 = \{ isTarget, root, estimator, graph } ->
    aStar isTarget estimator root graph

# aStarHelper does not die
expect
    dict = makeCosts "A"
    actual = aStarHelper (\_ -> Bool.true) constZero ["A"] dict (makeEmptyParents {}) testGraph2
    Result.isOk actual

## aStar terminates with empty graph
expect
    actual = aStar (\_ -> Bool.false) constZero "A" emptyGraph
    expected = Err NotFound
    actual == expected

## aStar It terminates when target not found
expect
    actual = aStar (\_ -> Bool.false) constZero "A" testGraph2
    expected = Err NotFound
    actual == expected

## aStar finds the one starting with "C"
expect
    actual =
        aStar (\v -> Str.startsWith v "C") constZero "A" testGraph2
        |> Result.map .0
    dbg actual

    expected = Ok "Ccorrect"

    actual == expected

# ## aStar finds the one starting with "B"
expect
    actual =
        aStar (\v -> Str.startsWith v "B") constZero "A" testGraph2
    expected = Ok ("B", ["A", "B"])
    actual == expected

# A helper function for performing A* search.
#
# `isTarget`   : A function that returns true if a vertex is the target.
# `estimator`  : An estimator functions that cacluclates approx distance to target.
# `stack`      : List of vertices remaining.
# `costs`      : CostDict for looking up the cost to reach each node's parent
# `parents`    : Parents object for tracking each node's parent
# `graph`      : The graph to perform the search on.
aStarHelper : (a -> Bool),
    Estimator a,
    List a,
    CostDict a,
    Parents a,
    Graph2 a
    ->
    Result (a, Parents a) [NotFound]
aStarHelper = \isTarget, estimator, stack, costs, parents, graph ->
    sorter = priorityWithEstimate estimator
    myStack =
        List.keepOks stack \node -> findCost node costs
        |> List.sortWith sorter
        |> List.map .0

    step = \neighbors, rest, current, currentCost ->
        filtered =
            neighbors # discard the nodes we have already *seen*
            |> List.keepIf (\n -> Result.isErr (findCost n costs))
        # return a new search context
        {
            stack: List.concat rest filtered,
            parents: addParents current filtered parents,
            costs: addCosts filtered currentCost costs,
        }

    when myStack is
        [] ->
            # we have run out of nodes, Err
            # but We're done!
            Err NotFound

        [current, ..] ->
            # take the first node in the queue
            rest = List.dropFirst myStack 1
            if isTarget current then
                # We're done!
                Ok (current, parents)
            else
                # get the cost to our current node
                currentCost = findCost current costs |> Result.map .1 |> Result.withDefault 0

                # expand the current node neighbors
                when graph current is
                    Ok neighbors ->
                        # step with our current neighbor list
                        next = step neighbors rest current currentCost
                        # and recurse with updated values
                        aStarHelper isTarget estimator next.stack next.costs next.parents graph

                    Err _ ->
                        # no neighbors, keep going
                        aStarHelper isTarget estimator rest costs parents graph

## aStar finds shortest path to "C"
expect
    actual =
        aStar (\v -> Str.startsWith v "C") constZero "A" testGraphMultipath
    expected = Ok ("C", ["A", "C"])
    actual == expected

# ## It finds the one starting with "B"
expect
    actual =
        aStar (\v -> Str.startsWith v "B") constZero "A" testGraph2
    expected = Ok ("B", ["A", "B"])

    actual == expected

# ## It finds the shortest path
expect
    actual = aStar (\v -> Str.startsWith v "X") constZero "A" testGraphMultipath
    expected = Ok ("XYZ", ["A", "B", "XYZ"])
    actual == expected

testGraphMultipath =
    [
        ("A", ["D", "C", "B"]),
        ("C", ["D", "E", "F"]),
        ("D", ["H", "I", "J"]),
        ("B", ["XYZ"]),
        ("H", ["XYZ"]),
        ("I", []),
        ("J", []),
        ("XYZ", []),
    ]
    |> fromList2
emptyGraph = [] |> fromList2
testGraph2 =
    [
        ("A", ["B", "Ccorrect"]),
        ("B", ["D", "Ccorrect", "Cwrong"]),
        ("D", []),
        ("Ccorrect", []),
        ("Cwrong", []),
    ]
    |> fromList2
