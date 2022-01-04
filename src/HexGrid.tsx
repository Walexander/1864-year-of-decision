import React from 'react';
import { pipe } from 'fp-ts/function'
import { Ctx } from 'boardgame.io'
import * as U from './model/unit'
import './react-hexgrid.d'
// eslint-disable-next-line
import {
	HexGrid,
	Layout,
	Hexagon,
	Text,
	Path,
} from 'react-hexgrid'
import * as Board from './model/game-board'
import { GameMoves }  from './Game'
import { GameState } from './game-state'
import styled from 'styled-components'
import * as Cube from './model/coords/cube'
import { coordHasConflict } from 'model/unit-location'
import { SVGChit } from 'Chit/Token'
const { Cell } = Board
export interface PropTypes {
	ctx: Ctx
	G: GameState
	previewCube?: Cube.Cube
	startCube?: Cube.Cube
	previewPath?: React.Component,
	children: any,
}

export const HexGridBoard = React.forwardRef<HTMLDivElement, PropTypes>(
	({G, previewCube, children}, ref) => {
		const layoutProps = {
			className: 'game',
			size: {x: 15, y: 15},
			spacing: 1.25,
			flat: true,
			origin: {x: 0, y: 0},
		}
		return (
			<Wrapper ref={ref}>
				<HexGrid width={1200} height={700} viewBox="-50 -50 100 100">
					<Layout {...layoutProps}>
						{Board.map(toCell)(G.hexgrid)}
						{children}
					</Layout>
				</HexGrid>
			</Wrapper>
		)

		function toCell(cell: Board.Cell.Cell) {
			const isConflict = coordHasConflict(cell.cube)(G)
			const isCurrent = !!G.combatCell && Cell.Eq.equals(cell, G.combatCell)
			return (
				<HexCell
					isConflict={isConflict}
					isCurrent={isCurrent}
					isPreview={
						previewCube
							? Cube.equals(cell.cube, previewCube)
							: false
					}
					cell={cell}
				/>
			)
	}
})

interface CellProps {
	cell: Board.Cell.Cell
	isPreview: boolean
	isConflict: boolean
	isCurrent: boolean
}

const HexCell: React.FC<CellProps> = ({
	isConflict,
	isCurrent,
	isPreview,
	cell: c,
}) => {
	const classList = [
		c.owner ? '--' + c.owner.toLowerCase() : '',
		isPreview ? '--preview' : '',
		isCurrent ? '--Current' : '',
		isConflict ? '--conflict' : '',
	].join(' ')

	return (
		<Hexagon className={classList} {...c.cube}>
			<Text>{Cell.show(c)}</Text>
		</Hexagon>
	)
}

const Wrapper = styled.div`
	g.hexagon-group {
		fill: var(--bg, black);
		fill-opacity: 0.2;
		&:hover {
			fill-opacity: 0.4;
		}

	}
	svg g.hexagon-group.--preview {
		fill-opacity: 0.8;
		g {
			fill-opacity: 0.8;
		}
	}
	g polygon {
		stroke: var(--bg);
		stroke-width: 0.2;
	}
	text {
		font-size: 0.175em;
		fill: #fff;
		fill-opacity: 0.9;
	}
	svg path {
		fill: none;
		stroke: #03090a;
		stroke-width: 0.2em;
		stroke-opacity: 0.9;
		stroke-linecap: round;
		stroke-linejoin: round;
	}
	.--unionplayer {
		--bg: #2e6287;
	}
	.--csaplayer {
		--bg: #7c6754;
	}
	.--conflict {
		g {
			fill: darkred;
			fill-opacity: 0.4;
		}
	}
`
