import { pipe } from 'fp-ts/function'
import { GameMoves } from '../Game'
import * as A from 'fp-ts/Array'
import { useState, useEffect, useRef, useLayoutEffect } from 'react'
import { useMachine } from 'react-robot'
import { Ctx } from 'boardgame.io'
import { toPlayer } from '../model/player'
import { machine, Context, ActionTypes, States } from '../select-machine'
type Position = { x: number; y: number }

type R = [React.RefObject<HTMLDivElement>, Position[]]

export const useCellPositions = (): R => {
	const ref = useRef<HTMLDivElement>(null)
	const [positions, setPositions] = useState<Position[]>([])
	useLayoutEffect(() => {
		if (!ref.current) return
		setPositions(getCoordinates(ref.current as HTMLElement))
	}, [])

	return [ref, positions]
}

function getCoordinates(element: HTMLElement) {
	const output = pipe(
		element.querySelectorAll('.hexagon-group'),
		Array.from,
		A.map((a: HTMLElement) => a.getBoundingClientRect()),
		A.map((r) => ({
			x: Math.floor(r.left) + r.width / 2,
			y: Math.floor(r.top) + r.height / 2,
		}))
	)
	return output
}

type M = [States, Context, Function]
export const useMoveMachine = (
	ctx: Ctx,
	{ makeMove, setMission }: GameMoves
): M => {
	const [moveMachine, sendMoveMachine] = useMachine(machine)
	const currentPlayer = toPlayer(ctx.currentPlayer)
	const machinePlayer = moveMachine.context.player

	useEffect(() => {
		const { nextMove } = moveMachine.context
		if (!nextMove || moveMachine.name !== States.MoveReady) return
		sendMoveMachine(ActionTypes.MakeMove)
		makeMove(nextMove)
	}, [makeMove, sendMoveMachine, moveMachine.context, moveMachine.name])

	useEffect(() => {
		const { unitMission, unit } = moveMachine.context
		if (!unit || !unitMission || moveMachine.name !== States.MissionReady)
			return
		sendMoveMachine(ActionTypes.MissionSet)
		setMission(unit.unitId, unitMission)
	}, [moveMachine.context, setMission])

	useEffect(
		() =>
			currentPlayer == machinePlayer
				? void 0
				: sendMoveMachine(ActionTypes.Switch),
		[machinePlayer, currentPlayer]
	)
	return [moveMachine.name, moveMachine.context, sendMoveMachine]
}
