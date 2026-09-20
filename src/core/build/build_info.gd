extends Node
class_name BuildInfo

var provider_name := "debug-native"
var version := "0.0.0-dev"
var commit := "local"
var environment := "native"
var workflow_run := "local"

func initialize() -> void:
	if not OS.has_feature("web"):
		return

	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		push_warning("BuildInfo could not access the browser window.")
		return

	var build = window.OCC_BUILD
	if build == null:
		push_warning("OCC_BUILD metadata is missing; using development defaults.")
		return

	provider_name = str(build.provider)
	version = str(build.version)
	commit = str(build.commit)
	environment = str(build.environment)
	workflow_run = str(build.workflowRun)

func short_commit() -> String:
	if commit.length() <= 8:
		return commit
	return commit.substr(0, 8)
