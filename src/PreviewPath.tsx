import * as O from 'fp-ts/Option'
import * as Cube from './model/coords/cube'
import { pipe } from 'fp-ts/function'
import { Path } from 'react-hexgrid'
import { Context } from './select-machine'
import { coordForUnit } from './model/unit-location'
import { GameState } from './game-state'

interface PreviewPathProps {
	moveCtx: Context,
	unitLocations: GameState['unitLocations']
}

export const PreviewPath: React.FC<PreviewPathProps> = (props) => {
	const { moveCtx, unitLocations } = props
	const { unit, previewMove } = moveCtx
	return pipe(
		unit,
		O.fromNullable,
		O.chain((unit) => pipe(
			unitLocations,
			coordForUnit(unit)
		)),
		O.bindTo('start'),
		O.bind('move', () => O.fromNullable(previewMove)),
		O.map( ({start, move}) => <Path start={start} end={move.to} />),
		O.getOrElse( () => <></> )
	)
}

