import * as EQ from 'fp-ts/Eq'
import * as N from 'fp-ts/number'
import { CubeCoords } from './cube'

export interface OffsetCoords {
	row: number
	col: number
}
export interface Params {
	row: number
	col: number
	rows: number
	columns: number
}
export const of = ({ rows, row, col, columns }: Params) => ({
	row: row - Math.floor(rows / 2),
	col: col - Math.floor(columns / 2),
})

export function fromCube(cube: CubeCoords): OffsetCoords {
	return { col: cube.q, row: cube.r + (cube.q + (cube.q & 1)) / 2 }
}

export const show = (c: OffsetCoords) => `[${c.col}, ${c.row}]`

export const eqOffset: EQ.Eq<OffsetCoords> = EQ.getStructEq({
	row: N.Eq,
	col: N.Eq,
})
