import { suite, test } from '@testdeck/jest'
import { interpret } from 'robot3'
import * as SUT from '../src/combat-machine'
import * as Combat from '../src/model/combat'
import { not } from 'fp-ts/Predicate'
import * as GB from '../src/model/game-board'
import { Player } from '../src/model/player'
import * as U from '../src/model/unit'
import { setup } from '../src/game-state'
import { pipe } from 'fp-ts/lib/function'
import * as A from 'fp-ts/Array'
const gameState = setup()
@suite
export class CombatMachineTest {
	private service = interpret(SUT.machine, () => void 0, {
		picked: [],
		attacker: Player.UnionPlayer,
		attackCommands: [],
		units: pipe(
			gameState.units,
			A.map((unit) => U.getUnitInfo(unit)(gameState))
		),
	})
	private hqs = pipe(this.service.context.units, A.filter(U.isHq))

	private armies = pipe(this.service.context.units, A.filter(not(U.isHq)))

	@test 'should start in idle'() {
		expect(this.service.machine.state.name).toEqual(SUT.States.Idle)
	}
	@test 'send(Begin) should transition to Plan'() {
		this.service.send({ type: SUT.ActionTypes.Begin })
		expect(this.service.machine.state.name).toEqual(SUT.States.Plan)
	}
	@test 'send(Begin) should invoke child'() {
		this.service.send(SUT.ActionTypes.Begin)
		expect(this.service.machine.state.name).toEqual(SUT.States.Plan)
		const child = this.service.child
		expect(child.state.name).toEqual('idle')
	}
}
