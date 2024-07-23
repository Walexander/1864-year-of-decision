module [drawPads, resetColors, drawBottomImage, drawTitle, drawUnits, drawBoardRect, drawPlayerMove, drawHoverPositon, drawGrid, drawLaunchPad, drawLaunchTimer, drawGameTime, blitHexagon]
import w4.W4
import w4.Sprite
import w4.Task exposing [Task]
import Assets
import Hex
import Health

basePoint : Hex.Point
basePoint = { x: 5, y: 20 }

boardRect = {
    x: basePoint.x |> Num.toI32,
    y: basePoint.y |> Num.toI32,
    width: Num.toU32 150,
    height: Num.toU32 100,
}

drawGameTime = \elapsedSeconds ->
    W4.setShapeColors! { fill: Color2, border: Color4 }
    offsetX : I32
    offsetX = 32
    W4.oval! {
        x: 160 - offsetX - 10,
        y: boardRect.y - 5,
        width: 30,
        height: 20,
    }
    W4.setTextColors! { fg: Color1, bg: None }
    size = Str.countUtf8Bytes elapsedSeconds
    minusX = Num.toI32 (size - 1) * 4
    elapsedSeconds
        |> W4.text! {
            x: 160 - offsetX - minusX,
            y: (boardRect.y + 2),
        }

gameBorder = [
    Hex.doubled -1 -1,
    Hex.doubled 1 -1,
    Hex.doubled 3 -1,
    Hex.doubled 5 -1,
    Hex.doubled 7 -1,
    Hex.doubled 9 -1,
    Hex.doubled 11 -1,
    Hex.doubled 13 -1,
    Hex.doubled -1 1,
    Hex.doubled -1 3,
    Hex.doubled -1 5,
    Hex.doubled -1 7,
    Hex.doubled -1 9,
    Hex.doubled -1 11,
    Hex.doubled -1 13,
    Hex.doubled -1 15,
    Hex.doubled 0 16,
    Hex.doubled 2 16,
    Hex.doubled 4 16,
    Hex.doubled 6 16,
    Hex.doubled 8 16,
    Hex.doubled 10 16,
    Hex.doubled 12 16,
    Hex.doubled 13 1,
    Hex.doubled 13 3,
    Hex.doubled 13 5,
    Hex.doubled 13 7,
    Hex.doubled 13 9,
    Hex.doubled 13 11,
    Hex.doubled 13 13,
    Hex.doubled 13 15,
]
drawBorder = List.walk gameBorder (Task.ok {}) \task, cell ->
    task!
    Drawing.blitHexagon cell boardRect Assets.filledHex

drawBoardRect = \rect ->
    W4.setShapeColors! { fill: Color3, border: Color3 }
    W4.rect! {
        x: 0,
        y: boardRect.y - 5,
        width: 160,
        height: boardRect.height + 5,
    }
    W4.setShapeColors! { fill: Color1, border: Color1 }
    W4.rect! rect
# W4.setShapeColors! { fill: None, border: Color3 }
# drawBorder

armyColor = \army ->
    when army is
        Union -> Color2
        Confederates -> Color3

drawLaunchPad = \pad, owner, sprite ->
    color =
        when owner is
            Owned p -> armyColor p
            Unowned -> Color4
    W4.setTextColors! { fg: None, bg: color }
    drawGrid! pad sprite boardRect

drawGrid = \cubes, sprite, point ->
    List.walk cubes (Task.ok {}) \task, cell ->
        task!
        blitHexagon cell point sprite
# Task.loop cubes \cs ->
#     when cs is
#         [] -> Task.ok (Done {})
#         [next, .. as rest] ->
#             blitHexagon next point sprite
#             |> Task.map \_ -> Step rest
hexFudgePoint = { x: Hex.halfWidth + 1, y: Hex.halfHeight + 2 }
drawPath = \segments ->
    # Task.loop segments \segment ->
    #     when segment is
    #         Segment (from, to) -> W4.line from to
    #         End -> Task.ok {}
    List.walk segments (Task.ok {}) \task, segment ->
        task!
        when segment is
            Segment from to ->
                W4.line
                    (Hex.addPoint boardRect from |> Hex.addPoint hexFudgePoint)
                    (Hex.addPoint boardRect to |> Hex.addPoint hexFudgePoint)

            End -> Task.ok {}
# List.walkWithIndex path (Task.ok {}) \task, from, i ->
#     task!
#     List.get path (i + 1)
#     |> Result.map \to -> W4.line from to
#     |> Result.withDefault (Task.ok {})

drawPaths = \plannedPath, destPath, starting ->
    # position = Hex.addPoint boardRect starting
    # |> List.set 0 starting
    # |> Hex.pathToLine
    # |> List.set 0 position
    destLine = List.map destPath \cell -> Hex.hexToPixel cell
    # |> List.set 0 position

    plannedLine =
        plannedPath
        |> List.map \cell -> Hex.hexToPixel cell
    W4.setPrimaryColor! Color2
    drawPath! (plannedLine |> Hex.pathToLine)

    _ <-
        List.last destPath
        |> Result.map \cell -> drawHoverPositon cell
        |> Result.withDefault (Task.ok {})
        |> Task.await

    W4.setPrimaryColor! Color4
    drawPath (destLine |> List.set 0 starting |> Hex.pathToLine)

drawHoverPositon = \cell ->
    { x, y } =
        Hex.addPoint boardRect (Hex.hexToPixel cell)
        |> Hex.addPoint { x: Hex.halfWidth + 1, y: Hex.halfHeight + 2 }
    # xoffset = Hex.halfWidth |> Num.toFrac |> Num.div 2 |> Num.round
    # yoffset = Hex.halfHeight |> Num.toFrac |> Num.div 2 |> Num.round
    # # width = xoffset * 2 |> Num.toU32
    # height = yoffset * 2 |> Num.toU32
    # x = point.x |> Num.add boardRect.x
    # y = point.y |> Num.add boardRect.y
    W4.line! { x: x - 2, y: y } { x: x + 2, y }
    W4.line! { x: x, y: y - 2 } { x, y: y + 2 }
    W4.setShapeColors! { fill: None, border: Color4 }
    blitHexagon cell boardRect Assets.hex

drawPlayerMove = \move, _hovering, get, color, _isBlocked ->
    W4.setPrimaryColor! color
    when move is
        Selected id planned ->
            unit = get id
            (starting, destination) =
                unit
                |> Result.map \{ lastPath, position } -> (position, lastPath)
                |> Result.withDefault ({ x: 0, y: 0 }, [])
            drawPaths planned destination starting

        Finished | Destination _ _ -> Task.ok {}

drawUnit = \unit, bp, theArmy, isSelected ->
    point =
        Hex.addPoint bp unit.position
        |> Hex.addPoint { x: 4, y: 2 }

    drawTo = {
        x: point.x,
        y: point.y,
        flags: if unit.army == Union then
            []
        else
            [FlipX],
    }
    border = armyColor unit.army
    # fill = if unit.army == theArmy && isSelected then Color4 else None
    # W4.setShapeColors! { border: Color3, fill: None }
    # unitCell = unit.cell #Hex.pixToHex unit.position
    # blitHexagon! unitCell { x: boardRect.x, y: boardRect.y + 1 } Assets.hex
    # W4.setShapeColors! { border: Color4, fill: None }
    # currentCell = Hex.pixToHex unit.position
    # blitHexagon! currentCell { x: boardRect.x, y: boardRect.y + 1 } Assets.hex

    (readyColors, width) =
        when unit.readiness is
            Cooldown timer ->
                t =
                    unit.cooldownRate
                    |> Num.sub (Num.toF32 timer)
                    |> Num.div unit.cooldownRate
                w = Hex.lerp 0 Hex.hexWidth t |> Num.round
                (
                    { fill: Color2, border: Color4 },
                    w,
                )

            Ready -> ({ fill: Color2, border: Color4 }, Hex.hexWidth)
            Moving -> ({ fill: None, border: None }, Hex.hexWidth)
    W4.setShapeColors! readyColors
    outlinePoint = Hex.addPoint point { x: -2, y: -3 }
    W4.rect! {
        x: outlinePoint.x,
        y: outlinePoint.y,
        width: width |> Num.toU32,
        height: 3,
    }

    task =
        if isSelected then
            W4.setShapeColors { fill: None, border: if isSelected then Color3 else None }
            |> Task.await \_ ->
                W4.rect {
                    x: point.x  - 4,
                    y: point.y - 4,
                    width: 16,
                    height: 16,
                }
        else
            Task.ok {}

    task!
    W4.setShapeColors { border, fill: None }
    |> Task.await \_ -> Sprite.blit unit.sprite drawTo
    |> Task.await \_ ->
        when unit.health is
            Living hp ->
                drawHealthBar hp {
                    x: point.x - 2,
                    y: point.y + Hex.hexHeight + 3,
                }

            Dead _ -> Task.ok {}

drawUnits = \units, bp, choice, theArmy ->
    Task.loop units \unitsLeft ->
        when unitsLeft is
            [unit, .. as rest] ->
                isSelected = when choice is
                    Selected id _ | Destination id _ if unit.id == id -> Bool.true
                    _ -> Bool.false
                drawUnit unit bp theArmy isSelected
                |> Task.map \_ -> Step rest

            [] -> Task.ok (Done [])

drawHealthBar : Health.Health, Hex.Point -> _
drawHealthBar = \health, point ->
    height = Num.toU32 3
    width = Hex.hexWidth |> Num.toFrac |> Num.round |> Num.toU32
    baseRect = {
        width,
        height,
        x: point.x |> Num.toI32,
        y: point.y |> Num.sub 2 |> Num.toI32,
    }
    healthPercent = Health.health health
    healthBar = Num.toFrac width |> Num.mul healthPercent |> Num.round
    healthRect = {
        height,
        width: healthBar |> Num.toU32,
        x: baseRect.x,
        y: baseRect.y,
    }
    W4.setShapeColors! { fill: Color3, border: Color1 }
    W4.rect! baseRect
    W4.setShapeColors! { fill: Color4, border: Color1 }
    W4.rect healthRect

blitHexagon = \cell, point, sprite ->
    # x = point.x |> Num.add (cell.column |> Num.mul Hex.hexWidth) |> Num.sub Hex.halfWidth |> Num.toI32
    # y = point.y |> Num.add (cell.row |> Num.mul Hex.hexHeight) |> Num.sub Hex.halfHeight |> Num.toI32
    { x, y } = Hex.hexToPixel cell
    pt = { x: x + point.x, y: y + point.y }
    Sprite.blit! sprite pt

resetColors =
    W4.setDrawColors {
        primary: Color1,
        secondary: Color2,
        tertiary: Color3,
        quaternary: Color4,
    }

drawPads = \launchPads, getOwner ->
    # Task.loop launchPads \pads ->
    #     when pads is
    #         [nextPad, .. as rest] ->
    #             drawLaunchPad nextPad (getOwner nextPad) Assets.hex
    #             |> Task.map \_ -> Step rest
    #         [] -> Task.ok (Done [])
    List.walk launchPads (Task.ok {}) \task, launchPad ->
        task!
        drawLaunchPad launchPad (getOwner launchPad) Assets.hex

drawBottomImage = \sprite ->
    # W4.setShapeColors! { border: Color4, fill: Color1 }
    # W4.rect! {
    #     x: 1,
    #     y: 160 - 50,
    #     width: 158,
    #     height: 50,
    # }
    sub = Sprite.subOrCrash sprite { srcX: 0, srcY: 0, height: 40, width: 156 }
    resetColors!
    Sprite.blit! sub { x: 2, y: 160 - 45 }

drawTitle = \point ->
    W4.setShapeColors! { border: Color2, fill: Color4 }
    W4.rect! { height: point.y - 5 |> Num.toU32, width: 160, x: 0, y: 0 }
    W4.setTextColors! { bg: None, fg: Color1 }
    W4.text! " Year of Decision" { x: 10, y: 3 }
    resetColors

drawLaunchTimer = \remaining, total ->
    totalWidth = Hex.hexWidth |> Num.mul 3 |> Num.sub Hex.hexWidth |> Num.toFrac
    launchWindowHeight = 22
    launchWindowWidth = totalWidth + 12
    barX =
        Num.toFrac (boardRect.x + (Num.toI32 boardRect.width))
        |> Num.div 2
        |> Num.sub (launchWindowWidth / 2)
        |> Num.round
        |> Num.add 1
        |> Num.toI32

    barY =
        boardRect.height
        |> Num.add (Num.toU32 boardRect.y)
        |> Num.toFrac
        |> Num.div 2
        |> Num.round
        |> Num.sub (Num.round (Num.toFrac launchWindowHeight / 2)) # |> Num.sub (Num.round (Num.toFrac Hex.hexHeight / 2))
        |> Num.add 1
        |> Num.toI32

    windowDims = {
        width: launchWindowWidth |> Num.round,
        height: launchWindowHeight,
        x: barX,
        y: barY,
    }
    W4.setShapeColors! { border: Color2, fill: Color4 }
    W4.rect! windowDims
    msg =
        if remaining <= 0 then
            ""
        else if remaining < 10_000 then
            remaining
            |> Num.toFrac
            |> Num.div 100
            |> Num.round
            |> Num.toFrac
            |> Num.div 10
            |> Num.toStr
        else
            remaining |> Num.toFrac |> Num.div 1000 |> Num.round |> Num.toStr
    width =
        (Num.toFrac (total - remaining))
        |> Num.div (Num.toFrac total)
        |> Num.mul totalWidth
        |> Num.round

    baseX =
        windowDims.x
        |> Num.add (Num.round (Num.toFrac windowDims.width / 2))
        |> Num.sub (Num.round ((totalWidth) / 2))

    timerSize = Str.countUtf8Bytes msg
    W4.setShapeColors! { border: Color2, fill: None }
    launchBarX = baseX
    launchBarY =
        Num.toI32 windowDims.height
        |> Num.add barY
        |> Num.sub 10

    launchBar = {
        x: launchBarX,
        y: launchBarY,
        width: Num.round totalWidth,
        height: 6,
    }
    W4.rect! launchBar
    W4.setShapeColors! { border: Color1, fill: Color3 }
    # W4.rect! { x: baseX, y: barY + 8, width, height: 5 }
    W4.rect! { launchBar & width }

    x =
        Num.toFrac windowDims.x
        |> Num.add (Num.toFrac windowDims.width / 2)
        |> Num.sub (Num.toFrac timerSize |> Num.mul 8 |> Num.div 2)
        |> Num.round
    W4.setTextColors! { bg: None, fg: Color1 }
    msg |> W4.text! { x, y: barY + 3 |> Num.abs }
