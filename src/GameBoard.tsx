import React from 'react'
import styled from 'styled-components'
import { Ctx } from 'boardgame.io'
import { Crank  } from './Crank'
import * as A from 'fp-ts/Array'
import { pipe } from 'fp-ts/function'
import { UnitCard  } from './UnitCard'
import {
	States as MoveStates,
	ActionTypes as MoveActions,
} from './select-machine'
import { useCellPositions, useMoveMachine } from './hooks/use-game'
import { Player  } from './model/player'
import { GameMoves, CombatStage }  from './Game'
import { GameState } from './game-state'
import { HexGridBoard } from './HexGrid'
import { PreviewPath } from './PreviewPath'
import { UnitList } from './UnitList'
import { Combat } from './Combat'
import * as U from 'model/unit'
import * as UL from 'model/unit-location'
import * as C from 'model/combat'
import { Cell } from 'model/game-board/cell'
import { toPlayer } from './model/player'

export interface PropTypes {
	ctx: Ctx
	G: GameState
	events: any
	moves: GameMoves
}


export const GameBoard: React.FC<PropTypes> = (props) => {
	const { activePlayers, currentPlayer } = props.ctx
	const player = toPlayer(props.ctx.currentPlayer)
	const currentStage = activePlayers?.[currentPlayer]  || ''
	const { phase } = props.ctx

	const { planAttack, musterTroops, musterNext, turnCrank } = props.moves
	const { G, ctx } = props
	const [ gridRef, positions ] = useCellPositions()
	const [moveState, moveCtx, sendMove] = useMoveMachine(
		props.ctx,
		props.moves,
	)
	const { unit: selectedUnit } = moveCtx
	const onCellClick = (cell: Cell) => {
		phase === 'combat'
			? planAttack(cell)
			: sendMove({
				type: MoveActions.SelectCube,
				selected: cell.cube,
			})
	}

	const missionFactory = (_: U.MissionType) => void 0

	const status =
		ctx.phase + '/' + (currentStage || '') + ' @ turn #' + ctx.turn
	const formatter = new Intl.DateTimeFormat('default', {
		month: 'long',
		day: 'numeric',
		year: 'numeric',
	})
	const date = formatter.format( new Date(G.roundInfo.date) )
	return (
		<GameWrapper className={'--' + phase}>
			<GameHeader
				roundNumber={G.roundInfo.round}
				roundDate={date}
				moveState={moveState}
				phase={status}
				turnCrank={turnCrank}
				player={player}
			></GameHeader>
			<Controls>
				{selectedUnit ? (
					<UnitCard
						missionFactory={missionFactory}
						unit={U.getUnitInfo(selectedUnit)(G)}
					/>
				) : null}
			</Controls>
			<HexGridBoard
				ref={gridRef}
				previewCube={moveCtx.previewMove?.to}
				{...props}
			>
				<PreviewPath
					moveCtx={moveCtx}
					unitLocations={G.unitLocations}
				/>
			</HexGridBoard>
			<UnitList
				onCellClick={onCellClick}
				selectState={moveState}
				G={G}
				currentPhase={ctx.phase}
				currentPlayer={player}
				selectedUnit={selectedUnit}
				positions={positions}
				sendSelect={sendMove}
			/>
			{ctx.phase === 'combat' && props.G.combatCell ? (
				<Combat
					stage={currentStage as CombatStage}
					G={G}
					onReady={(orders: C.AttackCommand[]) =>
						musterTroops(orders)
					}
					moves={props.moves}
					attacker={player}
					units={pipe(
						G,
						UL.unitsByCoord(props.G.combatCell.cube),
						A.filter((u) => u.player === player),
						A.map((a) => U.getUnitInfo(a)(G)),
						A.filter((u) => u.mission === U.MissionType.ATTACK)
					)}
				/>
			) : null}
		</GameWrapper>
	)
}

export const Controls = styled.aside`
	display: flex;
	flex-direction: row;
	column-gap: 2rem;
	justify-content: flex-start;
	padding-left: 5rem;
	min-height: 8rem;
`

const Header = styled.aside`
	display: flex;
	justify-content: space-between;
	align-items: center;
	row-gap: 2rem;
	padding-left: 5rem;
`

interface HeaderProps {
	phase: string
	moveState: MoveStates
	player: Player,
	roundNumber: number,
	roundDate: string,
	turnCrank: Function
}
const GameHeader: React.FC<HeaderProps> = ({
	phase,
	roundNumber,
	roundDate,
	player,
	turnCrank,
}) => (
	<Header>
		<PlayerName className={'--' + player.toLowerCase()}>
			{player}
		</PlayerName>
		<div
			style={{
				alignItems: 'center',
				gap: '1rem',
				justifyContent: 'center',
				margin: 'auto',
				maxWidth: '800px',
				display: 'flex',
			}}
		>
			<div style={{ background: 'lightgrey', padding: '2rem' }}>
				<h4>{roundNumber} @ {roundDate.toString()}</h4>
				<h5>{phase}</h5>
			</div>
		</div>
		<div className="button-holder">
			<Crank onClick={() => turnCrank()}>End Turn</Crank>
		</div>
	</Header>
)

const GameWrapper = styled.main`
	display: flex;
	flex-direction: column;
	max-width: 1200px;
	margin: auto;
`
const PlayerName = styled.h1`
	margin-top: 1rem;
	font-size: 4rem;
	margin-bottom: 1.5rem;
	background: var(--primary);
	color: white;
	padding: 1.5rem 1.5rem;
	min-width: 25rem;
	text-align: left;
`
