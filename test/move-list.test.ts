import { suite, test } from '@testdeck/jest'
import { Player } from '../src/model/player'
import { pipe } from 'fp-ts/function'
import { MoveUnitCommand } from '../src/model/unit-location'
import * as SUT from '../src/model/move-list'
import { Cube } from '../src/model/coords/cube'
import { GameState, setup } from '../src/game-state'

@suite
export class MoveListModelTest {
	private moveList = SUT.of()
	private G: GameState = setup()
	private moveCommand: MoveUnitCommand = { unitId: 'Lee', to: Cube(0, 0, 0) }

	@test 'should be empty'() {
		expect(this.moveList.CSAPlayer.length).toBe(0)
		expect(this.moveList.UnionPlayer.length).toBe(0)
	}

	@test 'addMove() should add to list'() {
		const test = SUT.addMove(Player.UnionPlayer, {
			unitId: 'Lee',
			to: Cube(0, 0, 0),
		})
		const result = test(this.moveList)

		expect(result.UnionPlayer.length).toBe(1)
		expect(result.CSAPlayer.length).toBe(0)
	}

	@test 'reset(player) should remove player list'() {
		const setup = pipe(
			this.moveList,
			SUT.addMove(Player.UnionPlayer, this.moveCommand)
		)
		console.log('set up is ', setup.UnionPlayer)
		expect(setup.UnionPlayer.length).toBe(1)
		const test = SUT.reset(Player.UnionPlayer)
		expect(test).toBeInstanceOf(Function)
		const result = test(setup)
		console.log('result is ', result.UnionPlayer)
		expect(result.UnionPlayer.length).toEqual(0)
	}

	@test 'hasUnitMoved() should return function'() {
		const test = SUT.hasMoved('Lee')
		expect(test).toBeInstanceOf(Function)
	}

	@test 'hasUnitMoved() should return false when unit has not moved'() {
		const test = SUT.hasMoved('Lee')
		expect(test(this.moveList)).toBe(false)
	}

	@test 'hasUnitMoved() should return true when unit has moved'() {
		const listWithMoves = pipe(
			this.moveList,
			SUT.addMove(Player.UnionPlayer, this.moveCommand)
		)
		const test = SUT.hasMoved(this.moveCommand.unitId)
		expect(test(listWithMoves)).toBe(true)
	}

	@test 'should append to player list'() {
		const test = SUT.addMove(Player.UnionPlayer, {
			unitId: 'Lee',
			to: Cube(0, 0, 0),
		})
		const result = test(this.moveList)
		expect(result.UnionPlayer.length).toBe(1)
		expect(result.CSAPlayer.length).toBe(0)
	}

	@test 'moveRemaining() should take a unit and return a function'() {
		const test = SUT.movesRemaning(Player.UnionPlayer)
		expect(test).toBeInstanceOf(Function)
	}

	@test 'moveRemaining() should return remining moves'() {
		const test = SUT.movesRemaning(Player.UnionPlayer)
		const result = test({
			...this.G,
			playerMoves: this.moveList,
		})
		expect(result).toBe(1)
	}
}
