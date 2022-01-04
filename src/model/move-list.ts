import { pipe } from 'fp-ts/lib/function'
import * as A from 'fp-ts/Array'
import { Player } from './player'
import { MoveUnitCommand } from './unit-location'
import * as U from './unit'
import { GameState } from 'game-state'

export interface PlayerMoves {
	[Player.UnionPlayer]: any[]
	[Player.CSAPlayer]: Array<any>
}
export function of(): PlayerMoves {
	return {
		[Player.UnionPlayer]: [],
		[Player.CSAPlayer]: [],
	}
}
export const PlayerMoves = of
export function addMove(
	player: Player,
	moveCommand: any
): (moveList: PlayerMoves) => PlayerMoves {
	return (moveList) => ({
		...moveList,
		[player]: pipe(moveList[player], A.append(moveCommand)),
	})
}

export function hasMoved(unitId: string): (moveList: PlayerMoves) => boolean {
	const notUnit = A.some((move: any) => move.unitId == unitId)
	return (moveList) =>
		pipe(moveList.CSAPlayer, A.concat(moveList.UnionPlayer), notUnit)
}

export function reset(player: Player) {
	return (moveList: PlayerMoves) => ({
		...moveList,
		[player]: [],
	})
}
type T = Pick<GameState, 'playerMoves' | 'units'>
export function movesRemaning(player: Player): (G: T) => number {
	return (G) => {
		const { playerMoves, units } = G
		const totalUnits = pipe(
			units,
			U.byPlayer(player),
			({ right }) => right.length
		)
		const totalMoves = playerMoves[player].length
		return totalUnits - totalMoves
	}
}
