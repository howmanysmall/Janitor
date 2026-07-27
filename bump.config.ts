import { defineConfig } from "bumpp";

const configuration = defineConfig({
	commit: true,
	confirm: true,
	files: ["package.json", "wally.toml"],
	noGitCheck: false,
	push: true,
	tag: true,
});

export default configuration;
