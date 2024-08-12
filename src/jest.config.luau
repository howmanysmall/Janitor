type Serialize = (
	value: unknown,
	config: unknown,
	indentation: number,
	depth: number,
	refs: unknown,
	printer: Serialize
) -> string
type Serializer = {
	serialize: Serialize,
	test: (value: unknown) -> boolean,
}
type JestConfiguration = {
	clearmocks: boolean?,
	displayName: nil | string | {
		name: string,
		color: string,
	},
	projects: {Instance}?,
	rootDir: Instance?,
	setupFiles: {ModuleScript}?,
	setupFilesAfterEnv: {ModuleScript}?,
	slowTestThreshold: number?,
	snapshotFormat: {
		printInstanceDefaults: boolean?,
		callToJSON: boolean?,
		escapeRegex: boolean?,
		escapeString: boolean?,
		highlight: boolean?,
		indent: number?,
		maxDepth: number?,
		maxWidth: number?,
		min: boolean?,
		printBasicPrototype: boolean?,
		printFunctionName: boolean?,
		theme: {[string]: string}?,
	}?,
	snapshotSerializers: {Serializer}?,
	testFailureExitCode: number?,
	testMatch: {string}?,
	testPathIgnorePatterns: {string}?,
	testRegex: {{string} | string}?,
	testTimeout: number?,
	verbose: boolean?,
}

local JestConfiguration: JestConfiguration = {
	displayName = "Janitor";
	testMatch = {"**/*.test"};
}
return JestConfiguration
