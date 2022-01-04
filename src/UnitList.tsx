import React from "react"
import * as A from 'fp-ts/Array'
import * as E from 'fp-ts/Either'
import styled from 'styled-components'
import { GameState  } from './game-state'
import * as B from './model/game-board'
import * as SEP from 'fp-ts/Separated'
import { pipe  } from 'fp-ts/function'
import { Unit, PlayerMoves as PM, Player } from './model/'
import { Chit, toChit  } from './Chit'
import { unitsByCoord } from 'model/unit-location'
import { States as MoveStates, ActionTypes } from './select-machine'
import * as C from 'model/coords/cube'
import * as UL from './model/unit-location'
import * as U from './model/unit'
import {Cell} from "model/game-board/cell"

type Position = {x: number, y: number}
export interface UnitListProps {
	sendSelect: Function,
	selectState: MoveStates,
	selectedUnit?: Unit.Unit,
	onCellClick: Function,
	currentPlayer: Player,
	G: GameState,
	positions: Position[],
	currentPhase: string,
}

export const UnitList: React.FC<UnitListProps> = (props) => {
	const sendPreview = (selected: C.Cube) =>
		props.sendSelect({ type: ActionTypes.PreviewMove, selected })
	const combatCell = props.G.combatCell
	const isCurrentCell = (cell: B.Cell.Cell) =>
		!!combatCell && B.Cell.Eq.equals(cell, combatCell)
				
	return (
		<GameCells>
			{pipe(
				props.G.hexgrid,
				B.map((cell, index: number) => (
					<CellOverlay
						className={[
							UL.needsResolution(cell)(props.G)
								? '--conflict'
								: '',
							isCurrentCell(cell) ? '--current' : ''
						].join(' ')}
						x={props.positions[index]?.x}
						y={props.positions[index]?.y}
						data-cell={cell.offset.col + cell.offset.row}
						onMouseOver={() => sendPreview(cell.cube)}
						onClick={(e) => props.onCellClick(cell)}
					>
						{pipe(
							props.G,
							unitsByCoord(cell.cube),
							A.map((unit) => U.getUnitInfo(unit)(props.G)),
							mapUnitsToAreas,
							(area) => toArea.render({ ...props, area })
						)}
					</CellOverlay>
				))
			)}
		</GameCells>
	)
}

interface ByMission {
	[U.MissionType.ATTACK]: U.GameInfo[],
	[U.MissionType.DEFEND]: U.GameInfo[],
}
interface Areas {
	[Player.UnionPlayer]: ByMission
	[Player.CSAPlayer]: ByMission 
}
type RenderAreaProps = UnitListProps & { area: Areas }
const toArea = {
	render: ({ area, ...props }: RenderAreaProps) => (
		<AreaUnitList className="area-unit-list">
			{pipe(
				Object.entries(area),
				A.map(([player, missions]) => (
					<li
						className={
							'--' + player.toLowerCase() + ' ara-unit-list-item'
						}
					>
						{byMission.render({ ...props, missions })}
					</li>
				))
			)}
		</AreaUnitList>
	),
}

const byMission = {
	render: ({
		missions,
		...props
	}: UnitListProps & { missions: ByMission }) => {
		const attackers = missions[U.MissionType.ATTACK]
		const defenders = missions[U.MissionType.DEFEND]
		return (
			<MissionList className="mission-list">
				<li className="attackers">
					<UnitsMissionList className="attacker-list">
					{pipe(
						attackers,
						A.map((unit) => toChit.render({...props, unit}) )
					)}
					</UnitsMissionList>
				</li>
				<li className="defenders">
					<UnitsMissionList className="defenders-list">
					{pipe(
						defenders,
						A.map((unit) => (
							<li>{toChit.render({...props, unit})}</li>
						)
					))}
					</UnitsMissionList>
				</li>
			</MissionList>
		)
	},
}

const MissionList = styled.ul`
	list-style-type: none;
	padding: 0;
	display: grid;
	grid-template-columns: repeat(2, minmax(45%, 1fr));
	grid-template-columns: repeat(2, min-content); 
	justify-content: space-evenly;
`

const UnitsMissionList = styled.ul`
	list-style-type: none;
	padding: 0;
	display: grid;
	grid-template-columns: repeat(2, 1fr);
	background: white;
	border: var(--bs, 2px) dashed var(--bc);
	position: relative;

	&:empty {
		--bs: 0;
	}
	&.defenders-list {
		--bc: green;
		--content: 'DEFEND';
		--bg-color: darkgreen;
		--mission-type: 'DEFEND';
	}
	&.attacker-list {
		--bc: red;
		--bg-color: darkred;
		--mission-type: 'ATTACK';
	}
	&.attacker-list,
	&.defenders-list {
		&:not(:empty):after {
			position: absolute;
			left: 50%;
			top: 0;
			content: var(--mission-type);
			transform: translate(-50%, -100%);
			background: var(--bg-color);
			color: white;
			line-height: 1.125;
			padding: 0.125rem 0.5rem;
			font-size: 1.5rem;
		}
	}
	&.--attack-mission {
		--x-modifier: -1;
	}
	&.--defend-mission {
	}
`

const AreaUnitList = styled.ul`
	display: grid;
	grid-template-rows: repeat(2, 1fr);
	align-items: baseline;
	row-gap: 2rem;
	padding: 0;
	list-style-type: none;
	justify-content: space-between;
	li {
		display: flex;
		flex-direction: column;
		justify-content: flex-end;
	}
	li:first-child {
		justify-content: flex-end;
	}
`

function mapUnitsToAreas(units: U.GameInfo[]): Areas {
	const todo = pipe(
		units,
		A.partition( (unit) => unit.player === Player.UnionPlayer ),
		SEP.bimap(mapDefense, mapDefense),
		({left, right}) => ({
			[Player.UnionPlayer]: right,
			[Player.CSAPlayer]: left,
		})
	)
	return todo
}

const mapDefense = (units: U.GameInfo[]): ByMission => {
	const todo = pipe(
		units,
		A.partition((unit) => unit.mission === U.MissionType.ATTACK),
		({left, right}) => ({
			[U.MissionType.ATTACK]: right,
			[U.MissionType.DEFEND]: left,
		})
	)
	return todo
}
const unitCanMove = (u: Unit.Unit, player: Player, G: GameState) => {
	return u.player === player && !PM.hasMoved(u.unitId)(G.playerMoves)
}
interface OverlayProps extends Position {
	className: string
	onMouseOver: (e: any) => void
	onClick: (e: any) => void
}
const CellOverlay = styled.li<OverlayProps>`
	display: block;
	position: absolute;
	color: white;
	min-width: 180px;
	min-height: 120px;
	left: ${(props) => props.x}px;
	top: ${(props) => props.y}px;
	transform: translate(-50%, -50%) scale(0.8);
	&:hover {
		z-index: 1;
	}
	&.--current {
		border: 0.5rem solid blue;
		&: before {
			border: 2px solid orange;
		}
	}
	.--combat &.--conflict {
		cursor: pointer;
		z-index: 1;
		&:after {
			font-size: 2.5rem;
			content: 'Fight!';
			padding: 0.5rem 1.5rem;
			display: block;
			position:absolute;
			left: 50%;
			top: 50%;
			transform: translate(-50%, -50%);
			background: red;
			color: yellow;
			cursor: pointer;
			z-index: 3;
		}
		&:before {
			background: url('glass.jpg');

			font-size: 2.5rem;
			content: '!';
			position: absolute;
			left: -15%;
			top: -10%;
			bottom: -10%;
			right: -15%; 
			bottom: 0;
			opacity: 0.4;
			filter: blur(3px);
			z-index:2;
		}
	}
`

const GameCells = styled.ul`
	display: grid;
	max-width: 500px;
	margin: auto;
	list-style-type: none;
	padding: 0;
	margin: 0;
`
