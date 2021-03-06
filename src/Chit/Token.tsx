import styled from 'styled-components'
import * as U from '../model/unit'
import { toRoman } from 'roman-numerals'

export const Wrapper = styled.svg`
	width: 8rem;
	height: 6rem;
	viewbox: auto;
	object-fit: contain;
	vertical-align: bottom;
	.bg {
		fill: var(--primary);
	}
	text {
		fill: currentColor;
	}
	ellipse {
		fill: var(--contrast);
	}
	.tag {
		fill: var(--accent);
	}
	line {
		stroke: white;
		stroke-width: 0.5rem;
	}
	.sp ellipse {
		fill: red;
	}
`
export const SVGChit: React.FC<{ unit: U.GameInfo }> = ({ unit }) => (
	<Wrapper
		className={'--' + unit.player.toLowerCase()}
		height="6rem"
		width="8rem"
		viewBox="-1 -1 800 600"
		preserveAspectRatio="xMidYMin"
	>
		<g id={unit.unitId} xmlns="http://www.w3.org/2000/svg">
			<title>
				{unit.player}/{unit.unitId}
			</title>
			<path
				className="bg"
				id="svg_1"
				d="m0,000l800,0l0,600l-800,0l0,-600z"
				opacity="undefined"
				stroke="#000"
				fill="#bf5f00"
			/>
			<text
				transform="matrix(5.62532 0 0 4.29306 -1063.93 -115.13)"
				stroke="#000000"
				text-anchor="middle"
				font-family="Noto Sans JP"
				font-size="24"
				stroke-width="0"
				id="svg_2"
				y="50.16705"
				x="255"
				fill="#f7efef"
			>
				{unit.unitId}
			</text>
			<path
				d="m215,181.5l349,0l0,159l-349,0l0,-159z"
				opacity="undefined"
				className="tag"
				stroke="#000"
				fill="#fff"
			/>
			<text
				text-anchor="start"
				font-family="'Inter'"
				className="initiative-rating"
				font-size="128"
				stroke-width="0"
				id="svg_6"
				y="511.5"
				x="142"
				stroke="#000"
				fill="#000000"
			>
				{unit.initiativeRating}
			</text>
			<text
				className="tactical-rating"
				text-anchor="start"
				font-family="'Inter'"
				font-size="128"
				stroke-width="0"
				id="svg_7"
				y="506.5"
				x="569"
				stroke="#000"
				fill="#000000"
			>
				{unit.tacticalRating}
			</text>
			<ellipse
				stroke="#000"
				ry="96"
				rx="93"
				id="svg_8"
				cy="476.5"
				cx="392"
				stroke-width="2"
				fill="#000000"
			/>
			<text
				transform="matrix(1.29996 0 0 1.11715 -128.185 -75.7735)"
				stroke="#000000"
				text-anchor="start"
				font-family="'Inter'"
				font-size="78"
				id="svg_10"
				y="518.91296"
				x="364.00033"
				stroke-width="0"
				fill="#eae1e1"
			>
				{unit._tag == 'HQ' ? null : toRoman(unit.qualityRating)}
			</text>
			<g id="svg_9" className="sp">
				<ellipse
					ry="119.47222131097482"
					rx="126.4999990351498"
					id="svg_15"
					cy="262.4722213109748"
					cx="663.5000028498471"
					fill="#ff0000"
					stroke="#fff"
				></ellipse>
				<text
					transform="matrix(5.79153 0 0 4.90286 -3237.34 -248.456)"
					fontFamily="Noto Sans JP"
					font-size="32"
					stroke-width="0"
					id="svg_16"
					y="114.71590118040663"
					x="657.5455159706912"
					fill="#000000"
					stroke="#fff"
					stroke-dasharray="2,2"
					font-weight="bold"
					font-style="normal"
				>
					{unit.sp}
				</text>
			</g>
			<line
				className="deco"
				stroke-width="2"
				id="svg_11"
				y2="181.5"
				x2="563"
				y1="337.5"
				x1="215"
				stroke="white"
				fill="white"
			/>
			<g className="stars">
				<path
					id="svg_17"
					d="m393,145.1881l20.10361,0l6.21217,-19.09835l6.21217,19.09835l20.10361,0l-16.26413,11.8033l6.21249,19.09835l-16.26414,-11.80362l-16.26414,11.80362l6.21249,-19.09835l-16.26414,-11.8033z"
					stroke="#000"
					fill="#fff"
				/>
				<path
					id="svg_19"
					d="m300,145.1881l20.10361,0l6.21217,-19.09835l6.21218,19.09835l20.1036,0l-16.26413,11.80329l6.21249,19.09836l-16.26414,-11.80362l-16.26414,11.80362l6.2125,-19.09836l-16.26414,-11.80329z"
					stroke="#000"
					fill="#fff"
				/>
			</g>
		</g>
{
	unit.isRouted ?
		<g xmlns="http://www.w3.org/2000/svg" id="svg_25">
			<path
				fill="#bc0045"
				stroke="#000"
				opacity="undefined"
				d="m23,30.5l106,0l0,532l-106,0l0,-532z"
				id="svg_20"
			/>
			<text
				fill="#e1ed04"
				x="-24.498"
				y="395.19771"
				id="svg_24"
				stroke-width="0"
				font-size="38"
				font-family="Noto Sans JP"
				text-anchor="start"
				stroke="#000"
				transform="rotate(90 73.2824 292.812) matrix(2.79579 0 0 2.34959 -73.6244 -606.625)"
			>
				ROUTED
			</text>
		</g> : null
}
	</Wrapper>
)
