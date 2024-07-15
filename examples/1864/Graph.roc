module [
    Graph,
    fromList,
    fromDict,
    aStar,
    bfs,
    dfs,
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

## Perform a breadth-first search on a graph to find a target vertex.
## [Algorithm animation](https://en.wikipedia.org/wiki/Breadth-first_search#/media/File:Animated_BFS.gif)
##
## - `isTarget` : A function that returns true if a vertex is the target.
## - `root`     : The starting vertex for the search.
## - `graph`    : The graph to perform the search on.
# dfs2 : (a -> Bool), a, Graph2 a -> Result (a, List a) [NotFound]
bfs : (a -> Bool), a, Graph2 a -> Result (a, List a) [NotFound] where a implements Hash & Eq & Inspect
bfs = \isTarget, root, graph ->
    bfsHelper isTarget [root] (Set.single root) (Dict.empty {}) graph
    |> Result.map \(t, paths) -> (t, makePaths t paths)

## It should find nodes starting with "C"
expect
    actual =
        bfs (\v -> Str.startsWith v "C") "A" testGraph2
        |> Result.map .0
    expected = Ok "Ccorrect"
    actual == expected

## It should find paths to nodes starting with "C"
expect
    actual =
        bfs (\v -> Str.startsWith v "C") "A" testGraph2
        |> Result.map .1
    expected = Ok ["A", "Ccorrect"]
    actual == expected

expect
    graph = \_ -> Err NotFound
    actual =
        bfs (\v -> Str.startsWith v "B") "A" graph
        |> Result.map .0
    expected = Err NotFound
    actual == expected

expect
    graph = \_ -> Err NotFound
    actual =
        bfs (\v -> Str.startsWith v "A") "A" graph
        |> Result.map .1
    expected = Ok ["A"]
    actual == expected
expect
    graph = \key ->
        when key is
            "A" -> Ok ["B"]
            _ -> Err NotFound
    actual =
        bfs (\v -> Str.startsWith v "B") "A" graph
    expected = Ok ("B", ["A", "B"])
    actual == expected
## Perform a depth-first search on a graph to find a target vertex.
## [Algorithm animation](https://en.wikipedia.org/wiki/Depth-first_search#/media/File:Depth-First-Search.gif)
##
## - `isTarget` : A function that returns true if a vertex is the target.
## - `root`     : The starting vertex for the search.
## - `graph`    : The graph to perform the search on.
# dfs : (a -> Bool), a, Graph a -> Result a [NotFound]
# dfs = \isTarget, root, @Graph graph ->
#     dfsHelper isTarget [root] (Set.empty {}) graph

dfs : (a -> Bool), a, Graph2 a -> Result (a, List a) [NotFound] where a implements Hash & Eq & Inspect
dfs = \isTarget, root, graph ->
    dfsHelper isTarget [root] (Set.empty {}) (Dict.empty {}) graph
    |> Result.map \(t, paths) -> (t, makePaths t paths)

makePaths = \v, paths ->
    iter = \p, ps ->
        Dict.get paths p
        |> Result.map \a -> iter a (List.prepend ps a)
        |> Result.withDefault ps
    iter v [v]

## It should find paths starting with "C"
expect
    actual =
        dfs (\v -> Str.startsWith v "C") "A" testGraph2
        |> Result.map .0
    expected = Ok "Ccorrect"
    actual == expected
## It should trace the correct path
expect
    actual =
        dfs (\v -> Str.startsWith v "C") "A" testGraph2
        |> Result.map .1
    expected = Ok ["A", "B", "Ccorrect"]
    actual == expected
expect
    graph = \_ -> Err NotFound
    actual =
        dfs (\v -> Str.startsWith v "B") "A" graph
        |> Result.map .0
    expected = Err NotFound
    actual == expected

expect
    graph = \_ -> Err NotFound
    actual =
        dfs (\v -> Str.startsWith v "A") "A" graph
        |> Result.map .1
    expected = Ok ["A"]
    actual == expected
expect
    graph = \key ->
        when key is
            "A" -> Ok ["B"]
            _ -> Err NotFound
    actual =
        dfs (\v -> Str.startsWith v "B") "A" graph
    expected = Ok ("B", ["A", "B"])
    actual == expected

sortList = \a, b ->
    if a.1 < b.1 then LT
    else if a.1 > b.1 then GT
    else EQ
# A helper function for performing the depth-first search.
#
# `isTarget` : A function that returns true if a vertex is the target.
# `stack`    : A List of vertices to visit.
# `visited`  : A Set of visited vertices.
# `graph`    : The graph to perform the search on.
aStarHelper : (a -> Bool), List a, Dict a I32, Dict a a, Graph2 a -> Result (a, Dict a a) [NotFound]
aStarHelper = \isTarget, stack, costs, parents, graph ->
    myStack =
        List.keepOks stack \node ->
            Dict.get costs node |> Result.map \cost -> (node, cost)
        |> List.sortWith sortList
        |> List.reverse
        |> List.map .0

    step = \neighbors, rest, current, currentCost ->
        filtered =
            neighbors
            |> List.keepIf (\n -> !(Dict.contains costs n))
        # newly explored nodes are added to LIFO stack
        newStack = List.concat rest filtered
        newParents = List.walk filtered parents \accum, discovered -> Dict.insert accum discovered current
        newCosts = List.walk filtered costs \accum, discovered ->
            Dict.insert accum discovered (currentCost + 1)
        { stack: newStack, parents: newParents, costs: newCosts }
    #         Dict.get costs n |> Result.map \cost -> (n cost)
    when myStack is
        [] ->
            Err NotFound
        [.., current] ->
            rest = List.dropLast myStack 1
            if isTarget current then
                Ok (current, parents)
            else
                currentCost = Dict.get costs current |> Result.withDefault 0
                # newVisited = Dict.insert visited current
                when graph current is
                    Ok neighbors ->
                        next = step neighbors rest current currentCost
                        aStarHelper isTarget next.stack next.costs next.parents graph
                    Err _ ->
                        aStarHelper isTarget rest costs parents graph


aStar : (a -> Bool), a, Graph2 a -> Result (a, List a) [NotFound] where a implements Hash & Eq & Inspect
aStar = \isTarget, root, graph ->
    initialCosts = Dict.single root 0
    aStarHelper isTarget [ root ] initialCosts (Dict.empty {}) graph
    |> Result.map \(t, paths) -> (t, makePaths t paths)

# aStarHelper does not die
expect
    dict = Dict.fromList [
        ("A", 0)
    ]
    actual = aStarHelper (\_ -> Bool.true) ["A"] dict (Dict.empty {}) testGraph2
    Result.isOk actual

## aStar terminates with empty graph
expect
    actual = aStar (\_ -> Bool.false) "A" emptyGraph
    expected = Err NotFound
    actual == expected

## aStar It terminates when target not found
expect
    actual = aStar (\_ -> Bool.false) "A" testGraph2
    expected = Err NotFound
    actual == expected

## aStar finds the one starting with "C"
expect
    actual =
        aStar (\v -> Str.startsWith v "C") "A" testGraph2
        |> Result.map .0
    dbg actual
    expected = Ok "Ccorrect"

    actual == expected

## aStar finds the one starting with "B"
expect
    actual =
        aStar (\v -> Str.startsWith v "B") "A" testGraph2
    expected = Ok ("B", ["A", "B"])

    actual == expected

## aStar finds shortest path to "C"
# expect
#     actual =
#         aStar (\v -> Str.startsWith v "C") "A" testGraphMultipath
#     expected = Ok ("CCorrect", ["A", "B", "CCorrect"])

    # actual == expected


## It finds the one starting with "B"
expect
    actual =
        aStar (\v -> Str.startsWith v "B") "A" testGraph2
    expected = Ok ("B", ["A", "B"])

    actual == expected

## It finds the shortest path
expect
    actual = aStar (\v -> Str.startsWith v "X") "A" testGraphMultipath
    expected = Ok ("XYZ", ["A", "B", "XYZ"])
    actual == expected


# A helper function for performing the depth-first search.
#
# `isTarget` : A function that returns true if a vertex is the target.
# `stack`    : A List of vertices to visit.
# `visited`  : A Set of visited vertices.
# `graph`    : The graph to perform the search on.
dfsHelper : (a -> Bool), List a, Set a, Dict a a, Graph2 a -> Result (a, Dict a a) [NotFound]
dfsHelper = \isTarget, stack, visited, parents, graph ->
    when stack is
        [] ->
            Err NotFound

        [.., current] ->
            rest = List.dropLast stack 1
            if isTarget current then
                Ok (current, parents)
            else if Set.contains visited current then
                dfsHelper isTarget rest visited parents graph
            else
                newVisited = Set.insert visited current
                when graph current is
                    Ok neighbors ->
                        filtered =
                            neighbors
                            |> List.keepIf (\n -> !(Set.contains newVisited n))
                            |> List.reverse

                        # newly explored nodes are added to LIFO stack
                        newStack = List.concat rest filtered
                        newParents : Dict a a
                        newParents = List.walk filtered parents \accum, discovered ->
                            Dict.insert accum discovered current
                        dfsHelper isTarget newStack newVisited newParents graph

                    Err _ ->
                        dfsHelper isTarget rest newVisited parents graph

# A helper function for performing the breadth-first search.
#
# `isTarget` : A function that returns true if a vertex is the target.
# `queue`    : A List of vertices to visit.
# `seen`  : A Set of all seen vertices.
# `graph`    : The graph to perform the search on.
bfsHelper : (a -> Bool), List a, Set a, Dict a a, Graph2 a -> Result (a, Dict a a) [NotFound]
bfsHelper = \isTarget, queue, seen, parents, graph ->
    when queue is
        [] ->
            Err NotFound

        [current, ..] ->
            rest = List.dropFirst queue 1

            if isTarget current then
                Ok (current, parents)
            else
                when graph current is
                    Ok neighbors ->
                        # filter out all seen neighbors
                        filtered = List.keepIf neighbors (\n -> !(Set.contains seen n))

                        # newly explored nodes are added to the FIFO queue
                        newQueue = List.concat rest filtered

                        # the new nodes are also added to the seen set
                        newSeen = List.walk filtered seen Set.insert

                        newParents : Dict a a
                        newParents = List.walk filtered parents \accum, discovered ->
                            Dict.insert accum discovered current

                        bfsHelper isTarget newQueue newSeen newParents graph

                    Err _ ->
                        bfsHelper isTarget rest seen parents graph

# Test BFS with multiple paths
expect
    actual =
        bfs (\v -> Str.startsWith v "C") "A" testGraph2
        |> Result.map .0
    expected = Ok "Ccorrect"

    actual == expected

expect
    actual =
        dfs (\v -> Str.startsWith v "X") "A" testGraphMultipath
    expected = Ok ("XYZ",  ["A", "D", "H", "XYZ"])

    actual == expected

expect
    actual =
        bfs (\v -> Str.startsWith v "X") "A" testGraphMultipath
    expected = Ok ("XYZ",  ["A", "B", "XYZ"])
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
