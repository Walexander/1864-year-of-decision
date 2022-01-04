import { interpret, Machine } from 'robot3'
import { suite, test } from '@testdeck/jest'
import { Player } from '../src/model/player'
import { machine, States } from '../src/model/supply'
import { Unit } from '../src/model/unit'

@suite
export class SupplyMachineTest {
	private unit: Unit = {
		_tag: 'HQ',
		moveLimit: 3,
		commandSpan: 2,
		player: Player.UnionPlayer,
		unitId: 'Grant',
		tacticalRating: 4,
		initiativeRating: 5,
	}
	private _service
	constructor() {
		this._service = interpret(machine, () => void 0, {
			unit: this.unit,
		})
	}

	@test 'it starts in supply'() {
		expect(this._service.machine.current).toEqual(States.InSupply)
	}
	@test 'it stays in supply on tick'() {
		this.supplyPhase(true)
		expect(this._service.machine.current).toEqual(States.InSupply)
	}

	@test 'it transitions to broken1 when no supply line'() {
		this.supplyPhase(false)
		expect(this._service.machine.current).toEqual(States.Broken1)
	}
	@test 'it transitions back to InSupply when re-supplied'() {
		this.supplyPhase(false)
		expect(this._service.machine.current).toEqual(States.Broken1)
		this.supplyPhase(true)
		expect(this._service.machine.current).toEqual(States.InSupply)
		this.supplyPhase(false)
		this.supplyPhase(false)
		expect(this._service.machine.current).toEqual(States.Broken2)
	}

	@test 'it transitions to broken2 when still no supply line'() {
		this._service.send({ type: 'tick', supplied: false })
		expect(this._service.machine.current).toEqual(States.Broken1)
		this._service.send({ type: 'tick', supplied: false })
		expect(this._service.machine.current).toEqual(States.Broken2)
	}

	@test 'it transitions to Reduced supply after a third time'() {
		this._service.send({ type: 'tick', supplied: false })
		expect(this._service.machine.current).toEqual(States.Broken1)
		this._service.send({ type: 'tick', supplied: false })
		expect(this._service.machine.current).toEqual(States.Broken2)
		this._service.send({ type: 'tick', supplied: false })
		expect(this._service.machine.current).toEqual(States.Reduced)
	}

	@test
	'it transitions to InSUpply from Reduced, Broken1 and Broken2 states'() {
		this.supplyPhase(false)
		this.supplyPhase(false)
		expect(this._service.machine.current).toEqual(States.Broken2)
		this.supplyPhase(true)
		expect(this._service.machine.current).toEqual(States.InSupply)
	}

	supplyPhase(supplied: boolean) {
		this._service.send({
			type: 'tick',
			supplied,
		})
	}
}
