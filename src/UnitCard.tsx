import React from 'react'
import { Crank  } from './Crank'
import styled from 'styled-components'
import * as Cube from './model/coords/cube'
import * as U from './model/unit'
interface PropTypes {
	unit: U.GameInfo
	missionFactory: (mission: U.MissionType) => void
}


export const UnitCard: React.FC<PropTypes> = ({unit, missionFactory}) => {
	return (
		<Wrapper className={'--' + unit.player.toLowerCase()}>
			<h3>
				{unit.unitId} [{unit._tag}]
			</h3>
			<Stats>
				<div>
					<h4>Mission</h4>
					<h2 style={{ textTransform: 'capitalize' }}>
						{unit.mission}
					</h2>
				</div>
				<div>
					<h4>Location</h4>
					<h2>{Cube.show(unit.location)}</h2>
				</div>
				<div>
					<h4>Strength Points</h4>
					<h2>{unit.sp}</h2>
				</div>
			</Stats>
		</Wrapper>
	)
}

const Wrapper = styled.div`
	width: 100%;
	height: 100%;
	h4 {
		min-height: 1.125rem;
		margin: 0;
		line-height: 1.125rem;
	}
	h3 {
		padding: 0.25rem;
		line-height: 1;
		margin: 0;
		background: var(--primary);
		color: white;
	}
`

const Stats = styled.div`
	display: flex;
	column-gap: 2rem;
	justify-content: space-around;
	color: white;
	background: var(--contrast);
`
