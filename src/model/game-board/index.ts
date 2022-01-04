import * as GC from './cell'
import * as O from 'fp-ts/Option'
import * as RNA from 'fp-ts/ReadOnlyNonEmptyArray'
import * as A from 'fp-ts/Array'
import { CubeCoords } from '../coords/cube'

import * as f from 'fp-ts/function'
import { Cube } from '../coords'
import { MonoidSum } from 'fp-ts/lib/number'
import { Player } from '../player'

export * as Cell from './cell'
export interface Board {
	cells: RNA.ReadonlyNonEmptyArray<GC.Cell>
	rows: number
	columns: number
}
type F1 = <A>(f: (c: GC.Cell, index: number) => A) => (b: Board) => A[]
export const map: F1 = (f) => (b) => b.cells.map(f)

type CellFinder = (cells: Board) => O.Option<number>

interface BoardParams {
	rows: number
	columns: number
}
const fill = (count: number): RNA.ReadonlyNonEmptyArray<number> =>
	f.pipe(
		RNA.replicate(0)(count),
		RNA.mapWithIndex((i) => i)
	)

// eslint-disable-next-line
export function Board({ rows, columns }: BoardParams): Board {
	return {
		rows,
		columns,
		cells: f.pipe(
			RNA.Do,
			RNA.bind('row', () => fill(rows)),
			RNA.bind('col', () => fill(columns)),
			RNA.map((p) => GC.of({ rows, toggleCount: 0, columns, ...p }))
		),
	}
}
export default Board

export function has(coord: CubeCoords) {
	return (grid: Board): boolean =>
		f.pipe(
			grid,
			findByCubeCoords(coord),
			O.fold(
				() => false,
				() => true
			)
		)
}
export const modifyCell =
	(fa: (cell: GC.Cell) => GC.Cell) => (needle: CubeCoords) => {
		return (haystack: Board): Board =>
			f.pipe(
				haystack,
				findByCubeCoords(needle),
				O.chain((a) =>
					f.pipe(haystack.cells.slice(), A.modifyAt(a, fa))
				),
				O.chain((a) => (a.length > 0 ? RNA.fromArray(a) : O.none)),
				O.map((cells) => ({
					...haystack,
					cells,
				})),
				O.getOrElse(() => haystack)
			)
	}

export const setOwner = (owner: Player) => modifyCell(GC.setOwner(owner))

export const toggleCell = (needle: CubeCoords) => {
	return (haystack: Board): Board =>
		f.pipe(
			haystack,
			findByCubeCoords(needle),
			O.chain((a) =>
				f.pipe(haystack.cells.slice(), A.modifyAt(a, GC.toggle))
			),
			O.chain((a) => (a.length > 0 ? RNA.fromArray(a) : O.none)),
			O.map((cells) => ({
				rows: haystack.rows,
				columns: haystack.columns,
				cells,
			})),
			O.getOrElse(() => haystack)
		)
}

export const toggleAtIndex = (i: number) => {
	return ({ rows, columns, cells, ...rest }: Board): Board => {
		return f.pipe(
			cells.slice(),
			A.modifyAt(i, GC.toggle),
			O.chain(RNA.fromArray),
			O.map((cells) => ({
				rows,
				columns,
				cells,
			})),
			O.getOrElse(() => ({ ...rest, rows, columns, cells }))
		)
	}
}

export function indexFromCube(cube: CubeCoords) {
	return (board: Board): O.Option<number> =>
		f.pipe(board, findByCubeCoords(cube))
}

export function cellFromCube(cube: CubeCoords) {
	return (board: Board): O.Option<GC.Cell> =>
		f.pipe(
			board,
			indexFromCube(cube),
			O.map((a) => board.cells[a])
		)
}

export function cellNeighbors(coords: CubeCoords) {
	return (grid: Board): CubeCoords[] =>
		f.pipe(
			grid,
			cellFromCube(coords),
			O.map(({ cube }) => cube),
			O.map(Cube.neighbors),
			// O.map( A.filter( (a) => contains(a)(grid) )),
			O.fold(
				() => [],
				(a) => a
			)
		)
}

export function contains(p1: CubeCoords) {
	return (grid: Board): boolean =>
		f.pipe(
			grid.cells.slice(),
			A.findIndex((p2) => Cube.equals(p1, p2.cube)),
			O.fold(
				() => false,
				() => true
			)
		)
}

export function findByCubeCoords(needle: CubeCoords): CellFinder {
	return (haystack: Board) =>
		f.pipe(
			haystack,
			(a) => a.cells.slice(),
			A.findIndex((a: GC.Cell) => Cube.equals(a.cube, needle))
		)
}

export function toggleCountSum(grid: Board) {
	return f.pipe(
		grid.cells,
		RNA.foldMap(MonoidSum)((cell: GC.Cell) => cell.toggleCount)
	)
}

export const show = (grid: Board): any =>
	f.pipe(
		grid.cells,
		RNA.map(GC.show),
		RNA.chunksOf(grid.columns),
		RNA.map((a) => a.slice().join('--')),
		(a) => a.slice().join('\n')
	)
