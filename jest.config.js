module.exports = {
	preset: 'ts-jest',
	moduleDirectories: ['node_modules', 'src'],
	moduleNameMapper: {
		'src/(.*)': '<rootDir>/src/$1',
	},

	coverageThreshold: {
		global: {
			branches: 0,
			functions: 0,
			lines: 0,
			statements: 0,
		},
	},
}
