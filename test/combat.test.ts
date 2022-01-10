import { suite, test } from '@testdeck/jest'
import * as S from 'fp-ts/State'
import * as C from 'fp-ts/Console'
import * as A from 'fp-ts/Array'
import * as IO from 'fp-ts/IO'
import * as I from 'fp-ts/Identity'
import * as O from 'fp-ts/Option'
import * as B from '../src/model/game-board'
import { Player } from '../src/model/player'
import { flow, identity, pipe } from 'fp-ts/function'
import * as SUT from '../src/model/combat'
import { Cube } from '../src/model/coords/cube'
import { GameState, setup } from '../src/game-state'
import * as Board from '../src/model/game-board'
import * as U from '../src/model/unit'
import { UnitLocation } from 'model/unit-location'
import * as UL from '../src/model/unit-location'

@suite
export class CombatModelTest {
	private state = setup()

	@test 'getRatio() should exist'() {
		const result = SUT.getRatio
		expect(result).toBeInstanceOf(Function)
	}
	@test 'getRatio(25, 25) should round down'() {
		const result = SUT.getRatio(25, 25)
		expect(result).toEqual(1.00)
	}
	@test 'getRatio(8, 6) should down to 1.00'() {
		const result = SUT.getRatio(8, 6)
		expect(result).toEqual(1.25)
	}
	@test 'getRatio(8, 7) should down to 1.25'() {
		const result = SUT.getRatio(8, 7)
		expect(result).toEqual(1.00)
	}
	@test 'getRatio(19,7) should be 2.75'() {
		const result = SUT.getRatio(19, 7)
		expect(result).toEqual(2.50)
	}

	@test 'getAttacker() should identify the attacking player'() {
		const cell = this.state.hexgrid.cells[0]
		const to = cell.cube
		const unitId = 'First'
		const unitLocations = UL.moveUnit({ unitId, to })(
			this.state.unitLocations
		)
		const missionList = U.setUnitMission(
			unitId,
			U.MissionType.ATTACK
		)(this.state.missionList)
		const state = {
			...this.state,
			unitLocations,
			missionList,
		}
		const result = SUT.getAttacker(state)(cell)
		// const todo = pipe(
		// 	state,
		// 	UL.unitsByCoord (cell.cube),
		// 	A.filter (U.isHq),
		// 	A.map( (a) => U.getUnitInfo (a) (G) ),
		// 	A.filter (isAttacker),
		expect(result).toEqual(Player.CSAPlayer)
	}

	@test.skip 'should remove eliminated units'() {
		const cell = this.state.hexgrid.cells[0]
		const to = cell.cube
		const unitId = 'First'
		const unitLocations = UL.moveUnit({ unitId, to })(
			this.state.unitLocations
		)
		const missionList = U.setUnitMission(
			unitId,
			U.MissionType.ATTACK
		)(this.state.missionList)
		const state = {
			...this.state,
			unitLocations,
			missionList,
		}

		const result = SUT.getAttacker(state)(cell)
		// const todo = pipe(
		// 	state,
		// 	UL.unitsByCoord (cell.cube),
		// 	A.filter (U.isHq),
		// 	A.map( (a) => U.getUnitInfo (a) (G) ),
		// 	A.filter (isAttacker),
		expect(result).toEqual(Player.CSAPlayer)
	}

	@test'adjustedTactical should return sane value'() {
		const r = SUT.modifiedTacticalRating(5)(5)
		expect(r).toEqual(6)
	}
	@test 'getResults should be curried'() {
		const r =  SUT.Result.getCombatResult(0.75) (-2)
		console.log('got result ', r)
		expect(r).toStrictEqual({
			attacker: {loss: 0.2, routed: true, pows: 0},
			defender: {loss: 0.03, routed: false, pows: 0}
		})

	}
	@test 'applyPOWLosses should apply results'() {
		const r =  SUT.Result.getCombatResult(0.75) (-2)
		console.log('got result ', r)
		expect(r).toStrictEqual({
			attacker: {loss: 0.2, routed: true, pows: 0},
			defender: {loss: 0.03, routed: false, pows: 0}
		})

	}
}
import * as AP from 'fp-ts/Apply'
import * as RE from 'fp-ts/Reader'

const addC = (a: number) => (b: number) => a + b
const add = (a: number, b: number) => a + b
interface Deps {
	minLength: number
}
type MyReader = RE.Reader<Deps, string>

function f(i: string): MyReader {
	return (r) => new Array(r.minLength).fill(i).join('--')
}
function g(n: number): MyReader {
	return (r) => (r.minLength > n ? r.minLength : n).toString()
}

export function foo(param: string): S.State<string, string> {
	return (state: string) => [param, state]
}
export function prepend(prefix: string): (to: string) => string {
	return (to) => prefix + to
}
export function after(suffix: string): (to: string) => string {
	return (to) => to + suffix
}
