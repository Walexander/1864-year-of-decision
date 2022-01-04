import { pipe } from 'fp-ts/function'
import * as M from 'fp-ts/Monoid'
import * as A from 'fp-ts/Array'
import { OffsetCoords } from './offset'

export interface CubeCoords {
	q: number
	r: number
	s: number
}

export type Cube = CubeCoords
export interface Params {
	offset: OffsetCoords
}

export function fromOffset({ col, row }: OffsetCoords): CubeCoords {
	const q = col
	const r = row - (col - (col & 1)) / 2
	return { q, r, s: -q - r }
}

export const equals = (p1: CubeCoords, p2: CubeCoords) =>
	p1.q === p2.q && p1.r === p2.r

export const show = (c: CubeCoords) => `{${c.q}; ${c.r}; ${c.s}}`

export const concat = (p1: CubeCoords, p2: CubeCoords): CubeCoords => ({
	q: p1.q + p2.q,
	r: p1.r + p2.r,
	s: p1.s + p2.s,
})

// eslint-disable-next-line
export const Cube = (q: number, r: number, s: number) => ({ q, r, s })
// eslint-disable-next-line
export const CubeCoords = Cube

export const neighbors = (p1: CubeCoords) =>
	pipe(
		[
			Cube(1, 0, -1),
			Cube(1, -1, 0),
			Cube(0, -1, 1),
			Cube(-1, 0, 1),
			Cube(-1, 1, 0),
			Cube(0, 1, -1),
		],
		A.map((c1) => concat(c1, p1))
	)
export const diffPoints: M.Monoid<CubeCoords> = {
	concat: (p1, p2) => ({
		q: p1.q - p2.q,
		r: p1.r - p2.r,
		s: p1.s - p2.s,
	}),
	empty: Cube(0, 0, 0),
}
export const sumPoints: M.Monoid<CubeCoords> = {
	concat,
	empty: Cube(0, 0, 0),
}

// function cube_distance(a, b):
// var vec = cube_subtract(a, b)
// return (abs(vec.q) + abs(vec.r) + abs(vec.s)) / 2
// function cube_distance(a, b):
// var vec = cube_subtract(a, b)
// return (abs(vec.q) + abs(vec.r) + abs(vec.s)) / 2
export const distance = (p1: CubeCoords, p2: CubeCoords): number => {
	const vec = diffPoints.concat(p1, p2)
	return Math.max(Math.abs(vec.q), Math.abs(vec.r), Math.abs(vec.s))
}
