import * as f from 'fp-ts/function'
import * as EQ from 'fp-ts/Eq'
import { Player } from '../player'
import { Cube, Offset } from '../coords'

export interface Cell {
	cube: Cube.CubeCoords
	offset: Offset.OffsetCoords
	owner?: Player
	toggleCount: number
	state: 'ON' | 'OFF'
}
type CellParams = Offset.Params & {
	toggleCount?: 0
}
export const show = (cell: Cell) => {
	return cell.owner
		? cell.owner
		: '' + ` ${cell.toggleCount} @ ${Cube.show(cell.cube)}`
}

// eslint-disable-next-line
export const Cell = ({ toggleCount = 0, ...p }: CellParams): Cell =>
	f.pipe(p, Offset.of, (offset) => ({
		...p,
		state: 'OFF',
		offset,
		cube: Cube.fromOffset(offset),
		toggleCount: toggleCount,
	}))

export const of = Cell
export const toggle = (c: Cell): Cell => ({
	...c,
	toggleCount: c.toggleCount + 1,
	state: c.state === 'OFF' ? 'ON' : 'OFF',
})

export const Eq: EQ.Eq<Cell> = {
	equals: (cell1: Cell, cell2: Cell) => Cube.equals(cell1.cube, cell2.cube),
}
export const setOwner =
	(owner: Player) =>
	(c: Cell): Cell => ({
		...c,
		owner,
	})
