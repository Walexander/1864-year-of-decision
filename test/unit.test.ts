import { suite, test } from '@testdeck/jest'
import { Player } from '../src/model/player'
import { pipe } from 'fp-ts/function'
import * as SUT from '../src/model/unit'
import { GameState, setup } from '../src/game-state'

@suite
export class UnitModelTest {
	private units = setup().units

	@test 'byPlayer() should exist'() {
		const result = SUT.byPlayer(Player.UnionPlayer)(this.units)
		expect(result.right.length).toEqual(1)
		expect(result.left.length).toEqual(2)
		const r2 = SUT.byPlayer(Player.CSAPlayer)(this.units)
		expect(r2.right.length).toEqual(2)
		expect(r2.left.length).toEqual(1)
	}
}
