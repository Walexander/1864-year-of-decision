import { suite, test } from '@testdeck/jest'
import {interpret} from 'robot3'
import * as SUT from '../src/Combat/plan-machine'
import * as Combat from '../src/model/combat'
import { not } from 'fp-ts/Predicate'
import * as GB from '../src/model/game-board'
import {Player} from '../src/model/player'
import * as U from '../src/model/unit'
import { setup } from '../src/game-state'
import {pipe} from 'fp-ts/lib/function'
import * as A from 'fp-ts/Array'
const gameState = setup()

@suite export class CombatMachineTest {
	private gameState = setup()
	private service = interpret(SUT.machine, () => void 0, {
		attacker: Player.UnionPlayer,
		picked: [],
		attackType: Combat.AttackType.REGULAR,
		attackCommands: [],
		commanded: [],
		strategy: Combat.Strategy.Regular,
		units: pipe(
			this.gameState.units,
			A.map((unit) => U.getUnitInfo(unit) (gameState))
		)
	})
	private hqs = pipe(
		this.service.context.units,
		A.filter(U.isHq)
	)

	private armies = pipe(
		this.service.context.units,
		A.filter(not(U.isHq))
	)


	addCommander(commander = this.hqs[0]) {
		this.service.send({
			type: SUT.ActionTypes.ChooseUnit,
			selected: commander
		})
		return commander
	}

	@test 'should start in idle'() {
		expect(this.service.machine.state.name).toEqual(SUT.States.Idle)	
	}

	@test 'should allow choosing commander'() {
		const commander = this.addCommander()
		expect(this.service.machine.state.name).toEqual(
			SUT.States.CommanderReady
		)
		expect(this.service.context?.commander).toStrictEqual(commander)
	}

	@test 'should remove commander from units list'() {
		const commander = this.addCommander()
		expect(this.service.context.units).not.toEqual(
			expect.arrayContaining([
				expect.objectContaining(commander)
			])
		)
	}
	@test 'should allow selection of commanded unit'() {
		const commander = this.service.context.units[2]
		const added = this.service.context.units[3]
		this.service.send({
			type: SUT.ActionTypes.ChooseCommander,
			selected: commander,
		})
		this.service.send({
			type: SUT.ActionTypes.AddCommandedUnit,
			selected: added,
		})
		expect(this.service.context.commanded).toStrictEqual([ added ])
	}

	@test 'should remove commanded units from units'() {
		const commander = this.service.context.units[2]
		const added = this.service.context.units[3]
		this.service.send({
			type: SUT.ActionTypes.ChooseCommander,
			selected: commander
		})
		this.service.send({
			type: SUT.ActionTypes.AddCommandedUnit,
			selected: added
		})
		expect(this.service.context.units).not.toEqual(
			expect.arrayContaining([
				expect.objectContaining(added)
			])
		)
	}

	@test 'should support adding multiple units'() {
		this.addCommander()
		const units = this.armies.slice(0, 1)
		units.map((u) =>
			this.service.send({
				type: SUT.ActionTypes.AddCommandedUnit,
				selected: u,
			})
		)

		expect(this.service.context.commanded).toStrictEqual(units)
	}

	@test 'should not allow adding more than units command span'() {
		const commander = this.addCommander(this.hqs[1]) as U.HQUnit
		expect(commander.commandSpan).toEqual(2)
		const units = this.armies.slice(0, 3)
		expect(units.length).toEqual(3)
		units.map((u) =>
			this.service.send({
				type: SUT.ActionTypes.AddCommandedUnit,
				selected: u,
			})
		)
		expect(this.service.context.commanded).not.toEqual(
			expect.arrayContaining([
				expect.objectContaining({
					unitId: units[2].unitId,
				})
			])
		)
	}
	@test 'should not allow non-hq commander to command units'() {
		const [ u1, u2  ] = this.armies
		this.service.send({
			type: SUT.ActionTypes.ChooseUnit,
			selected: u1
		})
		this.service.send({
			type: SUT.ActionTypes.AddCommandedUnit,
			selected: u2
		})
		expect(this.service.context.commanded).toStrictEqual([])
	}

	@test 'should add to attack commands when orders set'() {
		const commander = this.addCommander(this.hqs[1]) as U.HQUnit
		expect(commander.commandSpan).toEqual(2)
		this.service.send({
			type: SUT.ActionTypes.SetAttackType,
			attackType: Combat.AttackType.REGULAR
		})
		const { attackCommands } = this.service.context
		expect(this.service.machine.state.name).toEqual(
			SUT.States.Idle
		)
		expect(attackCommands.length).toEqual(1)
	}

	@test 'should set strategy'() {
		this.addCommander()
		this.service.send({
			type: SUT.ActionTypes.SetStrategy,
			strategy: Combat.Strategy.Flanking,
		})

		const { strategy } = this.service.context
		expect(strategy).toEqual(Combat.Strategy.Flanking)
		
	}
}
