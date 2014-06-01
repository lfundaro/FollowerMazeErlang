-module(follower_maze).
-compile(export_all).

init() -> 
	DispatcherPid = spawn_link(fun() -> dispatcher:init() end),
	{ok,ClientHubPid} = client_hub:init(DispatcherPid),
	{ok,EventHubPid} = event_hub:init(DispatcherPid),
	{ok,ClientHubPid,EventHubPid}.
