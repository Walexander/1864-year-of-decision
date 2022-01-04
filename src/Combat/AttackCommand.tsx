import React from 'react'
import styled from 'styled-components'
import { pipe, flow  } from 'fp-ts/function'
import { not  } from 'fp-ts/Predicate'
import * as M from '../combat-machine'
import { SVGChit  } from 'Chit/Token'
import * as U from 'model/unit'
import * as C from 'model/combat'
import * as A from 'fp-ts/Array'
import {Crank} from 'Crank'
import { useMachine } from 'react-robot'
import { machine, ActionTypes } from './attack-command-machine'
import { Player  } from 'model/player'
export interface PropTypes {
	units: U.GameInfo[]
	attacker: Player
	commander: U.GameInfo
	onSave: (command: C.AttackCommand) => void
}
export const AttackCommand: React.FC<PropTypes> = ({
	attacker,
	commander,
	units,
	onSave,
}) => {
	const [ myMachine, send ] = useMachine(machine, {
		attacker,
		units,
		commander,
		strategy: C.Strategy.Regular,
		attackType: C.AttackType.REGULAR,
		commanded: [],
	})
	const title = myMachine.name
	const {
		attackCommand,
		attackType,
		strategy,
		units: myAvailableUnits,
		commanded,
	} = myMachine.context
	const availableUnits = pipe(
		myAvailableUnits,
		A.sort(U.Ord),
		A.reverse,
		A.filter(not(U.isHq))
	)
	React.useEffect( () => {
		if(myMachine.name === 'ready' && attackCommand)
			onSave(attackCommand)
	}, [myMachine.name])
	return (
		<Wrapper>
			<h3 style={{ gridArea: 'title' }}>{title}</h3>
			<div style={{ gridArea: 'commander' }}>
				{commander ? (
					<SelectedUnit unit={commander} commanded={commanded} />
				) : null}
			</div>
			{U.isHq(commander) ?
			<div style={{ gridArea: 'available' }}>
				<h4>Assign to command</h4>
				<AvailableItemList>
					{availableUnits.map((unit) => (
						<UnitItem unit={unit} send={send} />
					))}
				</AvailableItemList>
				</div> : null
			}
			<div style={{ gridArea: 'attack' }}>
				<h4>Type</h4>
				<ButtonWrapper>
					{AttackTypeControls(send, attackType)}
				</ButtonWrapper>
			</div>
			<Strategy style={{ gridArea: 'strategy' }}>
				<h4>Maneuver</h4>
				<ButtonWrapper>
					{StrategyControls(send, strategy)}
				</ButtonWrapper>
			</Strategy>
			<div style={{ gridArea: 'save' }}>
				<Crank
					onClick={() => send({
						type: ActionTypes.SaveAttackCommands,
						command: machine.context.attackCommand,
					})}
				>Save</Crank>
			</div>
		</Wrapper>
	)
}

const ButtonWrapper = styled.div`
	display: grid;
	margin: auto;
	max-width: 148px;
	${Crank}.--selected {
		background: black;
		color: white;
		font-weight: 900;
	}
`
const Strategy = styled.div`
`
export const AttackTypeControls = (send: Function, current: C.AttackType) => (
	<>
		{pipe(
			Object.values(C.AttackType),
			A.map((type) => <Crank
				className={current === type ? '--selected' : ''}
				onClick={() => send({
					type: ActionTypes.SetAttackType,
					attackType: type
				})}
				>{type.replace('_', ' ')}</Crank>)
		)}
	</>
)

export const StrategyControls = (send: Function, current: C.Strategy) => (
	<>
		{pipe(
			Object.values(C.Strategy),
			A.map((type) => <Crank
				className={current === type ? '--selected' : ''}
				onClick={() => send({
					type: ActionTypes.SetStrategy,
					strategy: type,
				})}
				>{type}</Crank>)
		)}
	</>
)

export const Wrapper = styled.main`
	position: relative;
	display: grid;
	column-gap: 1rem;
	row-gap: 1rem;
	grid-template-areas:
		'title'
		'commander'
		'available'
		'strategy'
		'attack'
		'save'
	;
	${Crank} {
		text-transform: capitalize;
	}
	h3,
	h4 {
		margin: 0;
	}
`
const AvailableItemList = styled.ul`
	list-style-type: none;
	padding: 0;
	display: grid;
	column-gap: 1rem;
	row-gap: 1rem;
	grid-template-columns: repeat(auto-fit, 5rem);
	justify-content: center;
`
const UnitItem: React.FC<{unit: U.GameInfo; send: Function }> = ({
	send,
	unit,
}) => {
	const onClick = () =>
		send({
			type: ActionTypes.ChooseUnit,
			selected: unit,
		})
	return <Item onClick={onClick}>
		<SVGChit unit={unit} />
	</Item>
}

const Item = styled.li`
	cursor: pointer;
	svg {
		width: 100%;
		height: auto;
	}
`

const SelectedUnitWrapper = styled.main`
	top: 1rem;
	left: 1rem;
`
interface SelectedUnitProps {
	unit: U.GameInfo
	commanded: U.GameInfo[]
}
const SelectedUnit: React.FC<SelectedUnitProps> = (props) => {
	return (
		<SelectedUnitWrapper>
			<h4>Commander:</h4>
			<SVGChit unit={props.unit} />
			<h5>Commanding</h5>
			<CommandedItemList>
				{pipe(
					props.commanded,
					A.map((unit) => (
						<Item key={unit.unitId}>
							<SVGChit unit={unit} />
						</Item>
					)),
				)}
				{
				props.unit._tag === 'HQ' ?
					A.makeBy(
						(props.unit.commandSpan - props.commanded.length),
						(i) => <EmptySlot key={i} />
					) : null
				}
			</CommandedItemList>
		</SelectedUnitWrapper>
	)
}
export const EmptySlot = styled.li`
	position: relative;
	color: black;
	font-size: 0.75rem;
	border: 2px dashed black;
	border-radius: 0.125rem;
	background: white;
	aspect-ratio: 76/57;
	width: 100%;
	height: 100%;
	&:after {
		content: 'Available';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
	}
`
const CommandedItemList = styled(AvailableItemList)`
	max-width: 9rem;
	margin: auto;
	display: grid;
	grid-template-columns: repeat(2, minmax(12px, 1fr));
	row-gap: 0.25rem;
	column-gap: 0.25rem;
	padding: 0.5rem 0;
`
function getTitle(state: M.States) {
	switch(state) {
		case M.States.Idle: 
			return 'Choose Attacker';
		default:
			return 'Confirm'
	}
}
