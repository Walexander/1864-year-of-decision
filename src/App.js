import './App.css'
import { Client } from 'boardgame.io/react'
import { YearOfDecision } from './Game'
import { GameBoard } from './GameBoard'

export const GameApp = Client({ game: YearOfDecision, board: GameBoard })
export function App(props) {
	return (
		<div className="App">
			<main>
				<GameApp {...props} />
			</main>
		</div>
	)
}
export default App
