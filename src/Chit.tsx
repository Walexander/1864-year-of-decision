import React from 'react'
import { Wrapper as MissionWrapper, MissionControl } from './MissionControl'
import { SVGChit  } from './Chit/Token'
import * as PM from './model/move-list'
import * as U from 'model/unit'
import {
	ActionTypes,
	ActionTypes as MoveActions,
	SelectMachine,
	States as MoveStates,
} from './select-machine'
import { GameState } from './game-state'
import { GameMoves  } from './Game'
import { pipe  } from 'fp-ts/function'
import * as O from 'fp-ts/Option'
import * as A from 'fp-ts/Array'
import styled from 'styled-components'
import { Eq as unitEq, Unit } from './model/unit'

import { UnitListProps  } from './UnitList'
import { Player } from './model/player'
import {cellIndexForUnit} from 'model/unit-location'

interface ToComponent<A> {
	render: (element: A) => React.ReactElement
}
interface ChitProps extends UnitListProps {
	unit: Unit,
}

export const toChit: ToComponent<ChitProps> = {
	render: ({
		unit,
		selectState,
		selectedUnit,
		sendSelect,
		currentPlayer,
		currentPhase,
		G,
	}) => {
		const canMove =
			currentPhase === 'movement' && unitCanMove(unit, currentPlayer, G)
		const missionFactory = (mission: U.MissionType) => {
			selectedUnit?.unitId && sendSelect({
				type: ActionTypes.SetMission,
				mission
			})
		}
		const unitInfo = U.getUnitInfo(unit)(G)
		const props = {
			unit: unitInfo,
			canMove,
			mission: pipe(G.missionList, U.getUnitMission(unit)),
			selected: selectedUnit ? unitEq.equals(selectedUnit, unit) : false,
			onClick: () => {
				sendSelect({
					type: MoveActions.SelectUnit,
					selected: unit,
				})
			},
			selectState,
			factory: missionFactory,
		}
		return (<Chit {...props} />)
	},
}
const unitCanMove = (u: Unit, player: Player, G: GameState) => {
	return u.player === player && !PM.hasMoved(u.unitId)(G.playerMoves)
}
export interface PropTypes {
	unit: U.GameInfo
	selectState: MoveStates,
	selected: boolean
	mission: string 
	canMove: boolean
	onClick: React.MouseEventHandler<HTMLElement|SVGElement>
	factory: (mission: U.MissionType) => void
}
export const Chit: React.FC<PropTypes> = ({
	mission,
	canMove = true,
	selectState,
	factory,
	selected,
	onClick,
	unit,
}) => {
	const style = {
		'--disabled': '""',
		/* --disabled': canMove ? '""' : 'inherit', */
		'--modifier': unit.player === Player.UnionPlayer ? -1 : 1,
	}
	const classList = [
		'--' + unit.player.toLowerCase(),
		'--' + selectState,
		'--' + canMove ? 'moveable' : 'moved',
		selected ? '--selected' : '',
		mission ? `--${mission}-mission` : '',
	].join(' ')

	return (
		<Wrapper
			draggable
			onClick={onClick}
			style={style}
			className={classList}
		>
			<SVGChit unit={unit} />
			<MissionControl factory={factory} unit={unit} />
		</Wrapper>
	)
}
const Wrapper = styled.div<{ style: any }>`
	filter: brightness(var(--disabled, 0.75));
	box-shadow: 0px 0px 4px 4px var(--contrast);
	width: 8rem;
	height: 6rem;
	color: #fff;
	transform: scale(var(--scale, 0.75));

	&.--csaplayer {
		--y-modifier: -1.275;
	}
	&.--unionplayer {
		--y-modifier: 1.275;
	}

	&.--selected {
		position: relative;
		--scale: 1.125;
		z-index: 1;
	}
	&:not(.--selected) ${MissionWrapper} {
		display: none;
	}
`
const Title = styled.h6`
	margin: 0;
	font-size: 1.25rem;
`

const Tag = styled.div`
	max-width: 50%;
	aspect-ratio: 1.5/1;
	margin-left: auto;
	margin-right: auto;
	min-height: 1rem;
	border: 2px solid black;
	color: white;
	padding: 0.25rem;
	background: var(--contrast, black);
	text-align: center;
	border: 1px solid var(--accent);
`

const Rating = styled.div`
	font-weight: bold;
	font-size: 1.5rem;
	color: var(--accent);
`

const RatingRow = styled.div`
	display: flex;
	justify-content: space-between;
`

