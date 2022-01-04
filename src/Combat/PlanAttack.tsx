import React from 'react'
import styled from 'styled-components'

import { useMachine } from 'react-robot'
import * as M from './plan-machine'
import { machine, States } from './plan-machine'
import { Picked } from './Picked'
import { AttackCommand } from 'Combat/AttackCommand'
import { UnitList } from 'Combat/UnitList'
import * as U from 'model/unit'
import * as C from 'model/combat'
import {Player} from 'model/player'
export interface PropTypes {
	units: U.GameInfo[]
	onSave: (commands: C.AttackCommand[]) => void
	onReady: () => void
	stage: string
	attacker: Player
}
export const PlanAttack: React.FC<PropTypes> = ({onReady, onSave, units, attacker}) => {
	const [combatMachine, sendMachine] = useMachine(machine, {
		units,
		picked: [],
		attacker,
		attackType: C.AttackType.REGULAR,
		attackCommands: [],
		commanded: [],
		strategy: C.Strategy.Regular,
	})
	const state = combatMachine.name
	const commander = combatMachine.context.commander
	const orders = combatMachine.context.attackCommands
	const { units: availableUnits, attackCommands } = combatMachine.context

	const component = commander ?  <AttackCommand
		onSave={(command: C.AttackCommand) => {
			sendMachine({
				type: M.ActionTypes.SaveAttackCommand,
				command
			})
			onSave([command])
		}}
		attacker={attacker}
		units={availableUnits}
		commander={commander}
	/> : null

	return (
		<Wrapper>
		<h2>{state} total of { availableUnits.length } left? </h2>
			{
			/* economically-challenged fold on state */
				{
					[States.CommanderReady]: component,
					[States.Saving]: null,
					[States.Ready]: (
						<button onClick={() => { onReady() }}>
							Muster Troops
						</button>
					),
					[States.Idle]: (
						<>
							<h2>Choose unit</h2>
							<UnitList
								units={availableUnits}
								onClick={(unit: U.GameInfo) =>
									sendMachine({
										type: M.ActionTypes.ChooseCommander,
										selected: unit,
									})
								}
							/>
						</>
					),
				}[state]
			}
			<Picked orders={attackCommands} />
		</Wrapper>
	)
}


export const Wrapper = styled.main`
	color: white;
`
