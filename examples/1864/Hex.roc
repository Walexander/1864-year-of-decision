module [
    Doubled,
    Point,
    add,
    addPoint,
    pixelToHex,
    clamped,
    closestNeighbors,
    pixToHex,
    clamp,
    findGraph2,
    findGraph,
    hexDistance,
    neighborsOf,
    pathToLine,
    hexHeight,
    hexWidth,
    halfWidth,
    halfHeight,
    lerp,
    cubeLerp,
    hexToPixel,
    doubled,
    findPath,
    pointLerp,
]
import Graph

Point : { x : I32, y : I32 }
Doubled : {
    row : I32,
    column : I32,
}
hexWidth : I32
hexWidth = 11
hexHeight : I32
hexHeight = 6
halfWidth : I32
halfWidth = 6
halfHeight : I32
halfHeight = 3

doubled : I32, I32 -> Doubled
doubled = \column, row ->
    { column, row }

addPoint = \a, b -> {
    x: a.x + b.x,
    y: a.y + b.y,
}
hexToPixel : Doubled -> Point
hexToPixel = \{ row, column } -> {
    x: column |> Num.mul hexWidth,
    # |> Num.add 2,
    y: row |> Num.mul hexHeight,
    # |> Num.add 3,
}
# x = col * h + 2+
# col = (x - 2) / h+
# row = y - 3 / w+
pixToHex = \{ x, y } ->
    column =
        Num.toFrac (x + 2)
        |> Num.div (Num.toFrac hexWidth)
    cRound = column |> Num.round |> Num.toI32
    row =
        (y + 1)
        |> Num.toFrac
        |> Num.div (Num.toFrac hexHeight)
    rowRound = row |> Num.round |> Num.toI32

    if (rowRound + cRound) % 2 == 0 then
        dbg (rowRound, cRound)

        doubled cRound rowRound
    else
        rDiff = (Num.toFrac rowRound) - row
        cDiff = (Num.toFrac cRound) - column
        if (Num.abs rDiff) > (Num.abs cDiff) then
            dbg rowRound

            dbg cRound

            dbg (rowRound + cRound)

            myRow = if rDiff > 0 then rowRound - 1 else rowRound + 1
            doubled cRound myRow
        else
            myCol = if cDiff > 0 then cRound - 1 else cRound + 1
            doubled myCol rowRound
# expect
#     actual = pixToHex { x: 2, y: 3 }
#     expected = doubled 0 0
#     actual == expected &&
#     (pixToHex { x: 2, y: 4 }) == expected &&
#     (pixToHex { x: 2, y: 5 }) == expected

expect
    actual = pixToHex { x: 2, y: 10 }
    expected = doubled 0 2
    actual == expected
# expect
#     actual = pixToHex { x: 2, y: 8 }
#     expected = doubled 0 2
#     actual == expected
#     && (pixelToHex { x: 2, y: 9 }) == expected
#     && (pixelToHex { x: 2, y: 10 }) == expected
#     && (pixelToHex { x: 2, y: 11 }) == expected
#     && (pixelToHex { x: 2, y: 12 }) != expected

add = \a, b -> doubled (a.column + b.column) (a.row + b.row)
clampCube = \min, max -> \cell ->
        cell.column
        >= min.column
        && cell.row
        >= min.row
        && cell.column
        <= max.column
        && cell.row
        <= max.row

minCell = doubled 0 0
maxCell = doubled 12 15
clamped = clampCube minCell maxCell

expect
    clamped (doubled 0 0)
expect
    clamped (doubled -1 0)
    |> Bool.not
expect
    clamped (doubled 15 0)
    |> Bool.not
expect
    clamped (doubled 0 17)
    |> Bool.not
expect
    clamped (doubled 0 -1)
    |> Bool.not

clamp = \test ->
    c =
        if test.column < minCell.column then
            if minCell.column - test.column == 1 then
                minCell.column + 1
            else
                minCell.column
        else if test.column > maxCell.column then
            if (test.column - maxCell.column) == 1 then
                maxCell.column - 1
            else
                maxCell.column
        else
            test.column
    r =
        if test.row < minCell.row then
            if minCell.row - test.row == 1 then
                minCell.row + 1
            else
                minCell.row
        else if test.row > maxCell.row then
            if test.row - maxCell.row == 1 then
                maxCell.row - 1
            else
                maxCell.row
        else
            test.row
    { column: c, row: r }

expect
    actual = clamp (doubled 11 17)
    expected = doubled 11 15
    actual == expected

# expect
#     actual = clamp (doubled 14 18)
#     expected = doubled 12 16
#     actual == expected

# expect
#     actual = clamp (doubled 14 14)
#     expected = doubled 12 14
#     actual == expected
expect
    actual = clamp (doubled 1 17)
    expected = doubled 1 15
    actual == expected
expect
    actual = clamp (doubled -2 8)
    expected = doubled 0 8
    actual == expected

expect
    actual = clamp (doubled 14 8)
    expected = doubled 12 8
    actual == expected

expect
    actual = clamp (doubled 14 -2)
    expected = doubled 12 0
    actual == expected
# expect
#     clamp (doubled 12 18) == (doubled 12 16)

expect
    actual = clamp (doubled -4 -2)
    expected = doubled 0 0
    actual == expected
## Clamp should maintain (r + c) % 2 == 0 invariant
expect
    actual = clamp (doubled -1 1)
    expected = doubled 1 1
    actual == expected
expect
    actual = clamp (doubled 3 -1)
    expected = doubled 3 1
    actual == expected

doubleNeighbors = [
    doubled 1 1,
    doubled 0 2,
    doubled 1 -1,
    doubled -1 -1,
    doubled 0 -2,
    doubled -1 1,
]

neighborsOf = \cell ->
    List.map doubleNeighbors \n -> add n cell
    |> List.keepIf clamped

expect
    actual = neighborsOf (doubled 6 6)
    expected = [
        doubled 6 4,
        doubled 7 5,
        doubled 5 5,
        doubled 6 8,
        doubled 5 7,
        doubled 7 7,
    ]
    List.all expected \expec -> List.contains actual expec

expect
    n = neighborsOf (doubled 0 0)
    List.contains n (doubled 0 2)
    &&
    !(List.contains n (doubled 2 0))

expect
    actual = neighborsOf (doubled 12 6)
    expected = [
        doubled 12 8,
        doubled 11 5,
        doubled 12 4,
        doubled 11 7,
    ]
    List.all expected \expec -> List.contains actual expec

graph = \isBlocked -> \cell -> Ok (neighborsOf cell |> List.dropIf isBlocked)
findPath = \from, to -> cubeLerp from to

findGraph : Doubled, Doubled, (Doubled -> Bool) -> _
findGraph = \from, to, isBlocked ->
    Graph.astar {
        isTarget: \c -> c == to,
        estimator: \candidate -> hexDistance candidate to,
        # estimator: \_ -> 0,
        root: from,
        graph: graph isBlocked,
    }
    |> Result.map .1

findGraph2 : Doubled, Doubled, (Doubled -> Bool) -> Result (List Doubled) [NotFound]
findGraph2 = \from, to, isBlocked ->
    Graph.astar3 {
        isTarget: \c -> c == to,
        estimator: \candidate -> hexDistance candidate to,
        root: from,
        graph: graph isBlocked,
    }
    |> Result.mapErr \_ -> NotFound
    |> Result.map .1

## Should Err when all blocked
# expect
#     actual =
#         findGraph
#             (doubled 12 12)
#             (doubled 14 12)
#             (\_ -> Bool.true)
#     expected = Err NotFound
#     actual == expected

## Should find shortest path when one blocked
expect
    actual =
        findGraph
            (doubled 1 3)
            (doubled 3 3)
            (\{ column, row } -> column == 2 && row == 4)
    expected = [doubled 1 3, doubled 2 2, doubled 3 3]
    actual == Ok expected
## Should find shortest three-step path when one blocked
expect
    actual =
        findGraph
            (doubled 3 7)
            (doubled 1 3)
            # \_ -> Bool.false
            (\{ column, row } -> column == 2 && row == 4)
    expected = [doubled 3 7, doubled 2 6, doubled 1 5, doubled 1 3]
    actual == Ok expected
## findGraph should return a single item
## when from and to are equal
expect
    cell = doubled 12 12
    actual = findGraph cell cell (\_ -> Bool.false)
    expected = Ok [cell]
    actual == expected

## findGraph should Err when out of bounds
expect
    actual =
        findGraph
            (doubled 0 0)
            (doubled 2 0)
            (\_ -> Bool.true)
    expected = Err NotFound
    actual == expected

## findGraph should find one hop away
expect
    actual =
        findGraph
            (doubled 0 0)
            (doubled 0 2)
            (\_ -> Bool.false)
    expected = Ok [doubled 0 0, doubled 0 2]
    actual == expected

## findGraph should return straight line when none blocked
expect
    actual =
        findGraph
            (doubled 0 0)
            (doubled 0 4)
            (\_ -> Bool.false)
    expected = Ok [doubled 0 0, doubled 0 2, doubled 0 4]
    actual == expected

expect
    actual =
        findGraph
            (doubled 1 1)
            (doubled 3 0)
            (\_ -> Bool.false)
    expected = Err NotFound
    actual == expected
## findGraph should return straight line horizontally
expect
    actual =
        findGraph
            (doubled 0 0)
            (doubled 2 0)
            (\_ -> Bool.false)
    expected = Ok [doubled 0 0, doubled 1 1, doubled 2 0]
    actual == expected

pathToLine = \path ->
    List.mapWithIndex path \from, i ->
        List.get path (i + 1)
        |> Result.map \to -> Segment from to
        |> Result.withDefault End

hexDistance : Doubled, Doubled -> I32
hexDistance = \from, to ->
    dcol = Num.sub from.column to.column |> Num.abs
    drow = Num.sub from.row to.row |> Num.abs
    Num.sub drow dcol
    |> Num.toFrac
    |> Num.div 2
    |> Num.max 0.0
    |> Num.round
    |> Num.add dcol
# dcol + (Num.max 0 ((Num.sub drow dcol) |> Num.toFrac |> Num.div 2 |> Num.round))

expect
    actual = hexDistance (doubled 1 5) (doubled 1 3)
    expected = 1
    actual == expected
expect
    List.all
        (neighborsOf (doubled 1 5))
        \neighbor -> hexDistance (doubled 1 5) neighbor == 1

pointLerp : Point, Point, F32 -> Point
pointLerp = \a, b, progress -> {
    x: lerp (Num.toI32 a.x) (Num.toI32 b.x) progress |> Num.round,
    y: lerp (Num.toI32 a.y) (Num.toI32 b.y) progress |> Num.round,
}

## Lerping with 1.0

cubeLerp : Doubled, Doubled -> List Doubled
cubeLerp = \a, b ->
    n = hexDistance a b
    xs = List.range { start: At 0, end: At n }
    mul = 1 |> Num.div (Num.toFrac n)
    if n == 0 then
        [a]
    else
        List.walk xs [] \accum, i ->
            ii = mul |> Num.mul (Num.toFrac i)
            row = (lerp a.row b.row ii) |> Num.round
            col = (lerp a.column b.column ii) |> Num.round
            cell =
                if (row + col) % 2 == 0 then
                    doubled col row
                else
                    doubled col (row + 1)
            List.append accum cell

lerp : I32, I32, F32 -> F32
lerp = \a, b, t ->
    aa = Num.toFrac a
    bb = Num.toFrac b
    (bb - aa) |> Num.mul t |> Num.add aa

# drawHex = \cell, point, _sprite ->
#     x = point.x |> Num.add (cell.column |> Num.mul hexWidth) |> Num.sub halfWidth |> Num.toI32
#     y = point.y |> Num.add (cell.row |> Num.mul hexHeight) |> Num.sub halfHeight |> Num.toI32
#     # colors <- W4.getDrawColors |> Task.await
#     # W4.setShapeColors!{ fill: Color1, border: Color1 }
#     # W4.rect! {
#     #     x,
#     #     y,
#     #     height: Num.toU32 (2 * hexHeight),
#     #     width: Num.round (1.33 * Num.toFrac hexWidth),
#     # }
#     # W4.setShapeColors! colors
#     W4.setShapeColors! {border: Color4, fill: None }
#     # W4.oval! { x, y, height: Num.toU32 (2 * hexHeight), width: Num.round (Num.toFrac hexWidth |> Num.mul 1.33) }
#     Sprite.blit! Assets.filledHex { x: x, y : y }
#     W4.setTextColors! { fg: Color1, bg: None }
#     Task.ok {x, y}
# Sprite.blit sprite { x: Num.toI32 x, y: Num.toI32 y }

closestNeighbors = \from, to ->
    neighborsOf to
    |> List.sortWith \a, b -> Num.compare (hexDistance from a) (hexDistance from b)

pixelToHex = \{ x, y } ->
    base = 0.57735
    baseq = 0.6666667
    q = x |> Num.toF32 |> Num.mul baseq |> Num.div 8.0
    yy = y |> Num.toF32 |> Num.mul base
    xx = x |> Num.toF32 |> Num.mul -0.3333
    r = (xx + yy) |> Num.div 8.0
    roundCubic q r |> cubicToDouble

expect
    actual = pixelToHex { x: 0, y: 9 }
    expected = doubled 0 2
    actual == expected

roundCubic = \q, r ->
    s = (r + q) |> Num.mul -1.0
    qq = Num.round q
    rr = Num.round r
    ss = Num.round s
    qqDiff = Num.toF32 qq |> Num.sub (Num.toF32 q) |> Num.abs
    rrDiff = Num.toF32 rr |> Num.sub (Num.toF32 r) |> Num.abs
    ssDiff = Num.toF32 ss |> Num.sub (Num.toF32 s) |> Num.abs
    if qqDiff > rrDiff && qqDiff > ssDiff then
        { q: (ss + rr) |> Num.mul -1, s: ss, r: rr }
    else if rrDiff > ssDiff then
        { r: (qq + ss) |> Num.mul -1, q: qq, s: ss }
    else
        { s: (rr + qq) |> Num.mul -1, r: rr, q: qq }

cubicToDouble = \{ q, r } ->
    doubled q (2 * r + q)

