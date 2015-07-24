-module(follower_maze).
-export([init/0,start_follower_maze/0]).

% This is a environment setup function. Its main responsibility 
% is to create a Dispatcher process, a ClientHub and an EventHub. 
% Please refer to dispatcher.erl, client_hub.erl and event_hub.erl 
% respectively to find out more about them.
% Finally, it blocks listening to any kill signal that the user 
% might issue from the Erlang VM console. After trapping such a signal,
% it makes sure it forwards the signal to the processes created so they 
% also finish nicely (close sockets, etc).
start_follower_maze() ->
	process_flag(trap_exit, true),
	DispatcherPid = spawn(fun() -> dispatcher:init() end),
	{ok,ClientHubPid} = client_hub:init(DispatcherPid),
	{ok,EventHubPid} = event_hub:init(DispatcherPid),
	receive
		{'EXIT', Pid, shutdown} ->
			DispatcherPid ! {'EXIT', Pid, shutdown},
			ClientHubPid ! {'EXIT', Pid, shutdown},
			EventHubPid ! {'EXIT', Pid, shutdown},
			exit(normal)
	end.

% This is the starting point of the application. 
% It spawns a new process executing the start_follower_maze 
% function.
init() -> 
	spawn(?MODULE, start_follower_maze, []).

		
