module [Doubled, Point, pathToLine, hexHeight, hexWidth, halfWidth, halfHeight, lerp, cubeLerp, hexToPixel, doubled, drawHex, findPath, findGraph]
import Graph
import w4.Sprite

Point : { x : I16, y : I16 }
Doubled : {
    row : I32,
    column : I32,
}
hexWidth : I16
hexWidth = 12
hexHeight : I16
hexHeight = 6
halfWidth : I16
halfWidth = 6
halfHeight : I16
halfHeight = 3

doubled : I32, I32 -> Doubled
doubled = \column, row ->
    { column, row }

hexToPixel : Doubled -> Point
hexToPixel = \{ row, column } -> {
    x: column |> Num.toI16 |> Num.mul hexWidth |> Num.add 2 |> Num.toI16,
    y: row |> Num.toI16 |> Num.mul hexHeight |> Num.add 3 |> Num.toI16,
}

##
##     DoubledCoord(+2,  0), DoubledCoord(+1, -1),
#    DoubledCoord(-1, -1), DoubledCoord(-2,  0),
#    DoubledCoord(-1, +1), DoubledCoord(+1, +1),
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
maxCell = doubled 12 12
clamped = clampCube minCell maxCell
expect
    clamped (doubled 0 0)
expect
    clamped (doubled -1 0)
    |> Bool.not
expect
    clamped (doubled 13 0)
    |> Bool.not
expect
    clamped (doubled 0 13)
    |> Bool.not
expect
    clamped (doubled 0 -1)
    |> Bool.not

doubleNeighbors = [
    doubled 0 2,
    doubled 1 -1,
    doubled -1 -1,
    doubled 0 -2,
    doubled -1 1,
    doubled 1 1,
]

neighborsOf = \cell ->
    List.map doubleNeighbors \n ->
        add n cell
    |> List.keepIf clamped

expect
    actual = neighborsOf (doubled 6 6)
    expected = [
        doubled 6 8,
        doubled 7 5,
        doubled 5 5,
        doubled 6 4,
        doubled 5 7,
        doubled 7 7,
    ]
    actual == expected

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
    actual == expected

findPath = \from, to -> cubeLerp from to

findGraph : Doubled, Doubled, (Doubled -> Bool) -> Result (List Doubled) [NotFound]
findGraph = \from, to, isBlocked ->
    graph = \cell -> Ok
            (
                neighborsOf cell |> List.dropIf isBlocked
            )
    Graph.aStar (\c -> c == to) from graph |> Result.map .1

## Should Err when all blocked
expect
    actual =
        findGraph
            (doubled 12 12)
            (doubled 14 12)
            (\_ -> Bool.true)
    expected = Err NotFound
    actual == expected

## Should Return path when available
expect
    actual =
        findGraph
            (doubled 12 12)
            (doubled 12 12)
            (\_ -> Bool.false)
    expected = Ok [doubled 12 12]
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

## Should find one hop away
expect
    actual =
        findGraph
            (doubled 0 0)
            (doubled 0 2)
            (\_ -> Bool.false)
    expected = Ok [doubled 0 0, doubled 0 2]
    actual == expected
# expected = Ok [(doubled 0 0) (doubled 2 2)]

## findGraph should return straight line when none blocked
expect
    actual =
        findGraph
            (doubled 0 0)
            (doubled 0 4)
            (\_ -> Bool.false)
    expected = Ok [doubled 0 0, doubled 0 2, doubled 0 4]
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

pathToLine = \path, bp ->
    List.map path \cell ->
        point = Hex.hexToPixel cell
        {
            x: (point.x + bp.x) |> Num.toI32,
            y: (point.y + bp.y) |> Num.toI32,
        }

hexDistance : Doubled, Doubled -> I32
hexDistance = \from, to ->
    dcol = Num.sub from.column to.column |> Num.abs
    drow = Num.sub from.row to.row |> Num.abs
    dcol + (Num.max 0 ((Num.sub drow dcol) |> Num.toFrac |> Num.div 2 |> Num.round))

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
            row = (lerp a.row b.row ii) |> Num.floor
            col = (lerp a.column b.column ii) |> Num.floor
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

drawHex = \cell, point, sprite ->
    x = point.x |> Num.add (cell.column |> Num.toI16 |> Num.mul hexWidth) |> Num.sub halfWidth
    y = point.y |> Num.add (cell.row |> Num.toI16 |> Num.mul hexHeight) |> Num.sub halfHeight
    Sprite.blit sprite { x: Num.toI32 x, y: Num.toI32 y }

# _pixelToHex = \{ x, y } ->
#     base = 0.57735
#     baseq = 0.6666667
#     q = x |> Num.toF32 |> Num.mul baseq |> Num.div 8.0
#     yy = y |> Num.toF32 |> Num.mul base
#     xx = x |> Num.toF32 |> Num.mul -0.3333
#     r = (xx + yy) |> Num.div 8.0
#     roundCubic q r |> cubicToDouble

# roundCubic = \q, r ->
#     s = (r + q) |> Num.mul -1.0
#     qq = Num.round q
#     rr = Num.round r
#     ss = Num.round s
#     qqDiff = Num.toF32 qq |> Num.sub (Num.toF32 q) |> Num.abs
#     rrDiff = Num.toF32 rr |> Num.sub (Num.toF32 r) |> Num.abs
#     ssDiff = Num.toF32 ss |> Num.sub (Num.toF32 s) |> Num.abs
#     if qqDiff > rrDiff && qqDiff > ssDiff then
#         { q: (ss + rr) |> Num.mul -1, s: ss, r: rr }
#     else if rrDiff > ssDiff then
#         { r: (qq + ss) |> Num.mul -1, q: qq, s: ss }
#     else
#         { s: (rr + qq) |>Num.mul -1, r: rr, q: qq }

# cubicToDouble = \{ q, r } ->
#     doubled q (2 * r + q)

