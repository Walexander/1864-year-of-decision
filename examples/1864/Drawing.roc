module [
    drawPads,
    resetColors,
    drawBottomImage,
    drawTitle,
    drawSelectionIndicator,
    drawUnits,
    drawBoardRect,
    drawPlayerMove,
    drawHoverPositon,
    drawGrid,
    drawLaunchPad,
    drawLaunchTimer,
    drawGameTime,
    blitHexagon,
]
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

hexFudgePoint = { x: Hex.halfWidth + 1, y: Hex.halfHeight + 2 }
drawPath = \segments ->
    List.walk segments (Task.ok {}) \task, segment ->
        task!
        when segment is
            End -> Task.ok {}
            Segment from to ->
                fromPoint =
                    Hex.addPoint boardRect from
                    |> Hex.addPoint hexFudgePoint
                toPoint = Hex.addPoint boardRect to |> Hex.addPoint hexFudgePoint
                W4.line fromPoint toPoint

drawPaths = \plannedPath, destPath, starting, color ->
    destLine = List.map destPath \cell -> Hex.hexToPixel cell
    W4.setPrimaryColor! color
    plannedLine =
        plannedPath
        |> List.map \cell -> Hex.hexToPixel cell
    drawPath! (plannedLine |> Hex.pathToLine)
    W4.setShapeColors! { fill: None, border: Color4 }
    _ <-
        List.last destPath
        |> Result.map \cell -> drawHoverPositon cell Color4
        |> Result.withDefault (Task.ok {})
        |> Task.await

    W4.setPrimaryColor! Color4
    drawPath (destLine |> List.set 0 starting |> Hex.pathToLine)

drawHoverPositon = \cell, color ->
    W4.setPrimaryColor! color
    { x, y } =
        Hex.addPoint boardRect (Hex.hexToPixel cell)
        |> Hex.addPoint { x: Hex.halfWidth + 1, y: Hex.halfHeight + 2 }
    W4.line! { x: x - 2, y: y } { x: x + 2, y }
    W4.line! { x: x, y: y - 2 } { x, y: y + 2 }
    W4.setShapeColors! { border: color, fill: None }
    blitHexagon cell boardRect Assets.hex

drawPlayerMove = \move, get, color ->
    W4.setPrimaryColor! color
    when move is
        Selected id planned ->
            unit = get id
            (starting, destination) =
                unit
                |> Result.map \{ lastPath, position } -> (position, lastPath)
                |> Result.withDefault ({ x: 0, y: 0 }, [])
            drawPaths planned destination starting color

        Finished | Destination _ _ _ -> Task.ok {}

drawUnit = \unit, bp ->
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

    outlinePoint = Hex.addPoint point { x: -2, y: Hex.hexHeight + 2 }
    (readyColors, width) =
        when unit.readiness is
            Cooldown timer ->
                t =
                    unit.cooldownRate
                    |> Num.sub (Num.toF32 timer)
                    |> Num.div unit.cooldownRate
                w = Hex.lerp 0 Hex.hexWidth t |> Num.round
                (
                    { fill: Color2, border: None },
                    w,
                )

            Ready -> ({ fill: Color2, border: None }, Hex.hexWidth)
            Moving -> ({ fill: None, border: None }, Hex.hexWidth)
    W4.setShapeColors! { fill: None, border: Color4 }
    W4.rect! { x: outlinePoint.x, y: outlinePoint.y, width: Hex.hexWidth |> Num.toU32, height: 3u32 }
    W4.setShapeColors! readyColors
    W4.rect! {
        x: outlinePoint.x + 1,
        y: outlinePoint.y + 1,
        width: width - 2 |> Num.toU32,
        height: 1,
    }
    xOffset = if unit.army == Union then -2 else 8

    W4.setShapeColors { border, fill: None }
    |> Task.await \_ -> Sprite.blit unit.sprite drawTo
    |> Task.await \_ ->
        when unit.health is
            Living hp ->
                drawHealthBar hp {
                    x: point.x + xOffset,
                    y: point.y + 2,
                    # + Hex.hexHeight + 3,
                }

            Dead _ -> Task.ok {}

drawUnits = \units, bp ->
    Task.loop units \unitsLeft ->
        when unitsLeft is
            [unit, .. as rest] ->
                drawUnit unit bp # theArmy (isSelected unit.id)
                |> Task.map \_ -> Step rest

            [] -> Task.ok (Done [])

drawSelectionIndicator = \point, color ->
    width = 15
    height = 16
    topLeft =
        point
        |> Hex.addPoint boardRect
        |> Hex.addPoint { x: 0, y: -1 }
    topRight =
        topLeft
        |> Hex.addPoint { x: width, y: 0 }
    bottomRight =
        topLeft
        |> Hex.addPoint { x: width, y: height }
    bottomLeft =
        topLeft
        |> Hex.addPoint { x: 0, y: height }
    W4.setPrimaryColor! color
    W4.line! topLeft (Hex.addPoint topLeft { x: 4, y: 0 })
    W4.line! topLeft (Hex.addPoint topLeft { x: 0, y: 4 })
    W4.line! topRight (Hex.addPoint topRight { x: -4, y: 0 })
    W4.line! topRight (Hex.addPoint topRight { x: 0, y: 4 })
    W4.line! bottomLeft (Hex.addPoint bottomLeft { x: 0, y: -4 })
    W4.line! bottomLeft (Hex.addPoint bottomLeft { x: 4, y: 0 })
    W4.line! bottomRight (Hex.addPoint bottomRight { x: -4, y: 0 })
    W4.line bottomRight (Hex.addPoint bottomRight { x: 0, y: -4 })
# |> Task.await \_ ->
#     W4.rect {
#         x: drawPoint.x,
#         y: drawPoint.y,
#         width: 15,
#         height: 16,
#     }

drawHealthBar : Health.Health, Hex.Point -> _
drawHealthBar = \health, point ->
    width = Num.toU32 1
    height = Hex.hexHeight |> Num.toFrac |> Num.mul 1.5 |> Num.round |> Num.sub 1 |> Num.toU32
    baseRect = {
        width,
        height: height,
        x: point.x |> Num.toI32,
        y: point.y |> Num.sub 3 |> Num.toI32,
    }
    healthPercent = Health.health health

    healthBar =
        Num.toFrac height
        |> Num.mul healthPercent
        |> Num.round
        |> \barHeight -> if healthPercent < 1.0 then Num.min (height - 1) barHeight else barHeight
        |> Num.toU32
        |> Num.max 3u32
    healthRect = {
        width,
        height: healthBar,
        x: baseRect.x,
        y: baseRect.y + Num.toI32 (height - healthBar),
    }
    W4.setShapeColors! { fill: Color3, border: Color3 }
    W4.rect! baseRect
    W4.setShapeColors! { fill: Color4, border: Color4 }
    W4.rect healthRect

blitHexagon = \cell, point, sprite ->
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
    List.walk launchPads (Task.ok {}) \task, launchPad ->
        task!
        drawLaunchPad launchPad (getOwner launchPad) Assets.hex

drawBottomImage = \sprite ->
    sub = Sprite.subOrCrash sprite {
        srcX: 0,
        srcY: 0,
        height: 40,
        width: 156,
    }
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
    launchWindowHeight = 26
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
        |> Num.sub (Num.round (Num.toFrac launchWindowHeight / 2))
        |> Num.add 1
        |> Num.toI32

    windowDims = {
        width: launchWindowWidth |> Num.round,
        height: launchWindowHeight,
        x: barX,
        y: barY,
    }
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
    launchBarX = baseX
    launchBarY =
        Num.toI32 windowDims.height
        |> Num.add barY
        |> Num.sub 10

    launchBar = {
        x: launchBarX,
        y: launchBarY,
        width: Num.round totalWidth,
        height: 4,
    }

    x =
        Num.toFrac windowDims.x
        |> Num.add (Num.toFrac windowDims.width / 2)
        |> Num.sub (Num.toFrac timerSize |> Num.mul 8 |> Num.div 2)
        |> Num.round


    (fill, fg) =
        isFlashing =
            if remaining < 1_000 then
                Bool.true
            else if remaining < 5_000 then
                remaining % 500 > 250
            else if remaining < 10_000 then
                remaining % 1000 > 500
            else
                Bool.false
        # flashing =
        #     remaining < 1_000 |> Bool.and remaining % 100 > 100)
        #     |> Bool.or (remaining < 5_000 |> Bool.and remaining % 1_000 > 500
        if isFlashing then
           (Color3, Color1)
        else
           (Color1, Color3)
    shapeColor = { border: fg, fill }
    launchColors = { border: Color4, fill: fg }
    textColors = { bg: None, fg }

    W4.setShapeColors! shapeColor
    W4.oval! windowDims
    W4.setShapeColors! { border: Color2, fill: None }
    W4.rect! launchBar
    W4.setShapeColors! launchColors
    W4.rect! { launchBar & width }
    W4.setTextColors! textColors
    msg |> W4.text! { x, y: barY + 6 |> Num.abs }
