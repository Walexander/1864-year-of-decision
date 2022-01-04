import styled from 'styled-components'
import * as U from './model/unit'
import { Crank  } from './Crank'
export interface PropTypes {
	unit: U.GameInfo
	factory: (mission: U.MissionType) => void
}

export const MissionControl: React.FC<PropTypes> = ({ unit, factory }) => (
	<Wrapper>
		<Crank
			disabled={unit.mission === U.MissionType.DEFEND}
			onClick={() => factory(U.MissionType.DEFEND)}
		>
			Defend
		</Crank>
		<Crank
			disabled={unit.mission === U.MissionType.ATTACK}
			onClick={() => factory(U.MissionType.ATTACK)}
		>
			Attack
		</Crank>
	</Wrapper>
)

export const Wrapper = styled.aside`
	display: flex;
	flex-direction: row;
	padding: 0.15rem;
	border: 1px solid var(--primary, black);
	background: white;
	color: black;
	position: absolute;
	left: 50%;
	transform: translateX(-50%);
`
