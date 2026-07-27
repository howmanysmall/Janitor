import type { UserConfig } from "@commitlint/types";

const configuration: UserConfig = {
	extends: ["@commitlint/config-conventional"],
	rules: {
		"header-max-length": [2, "always", 72],
		"scope-case": [2, "always", "lower-case"],
		"subject-empty": [2, "never"],
		"subject-full-stop": [2, "never", "."],
		"type-case": [2, "always", "lower-case"],
		"type-enum": [
			2,
			"always",
			["feat", "fix", "refactor", "docs", "style", "test", "chore", "perf", "ci", "build"],
		],
	},
};

export default configuration;
