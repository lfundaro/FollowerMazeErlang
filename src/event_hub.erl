-module(event_hub).
-export([init/1]).

-define(PORT,9090).
 
 init(DispatcherPid) -> 
	generic_server:start_server(?PORT,DispatcherPid,fun handle/2).
 
% This is an implementation of the handle function that generic_server.erl 
% needs in order to process a new connection. In the case of this module, 
% the handle just forwards any message separated by newline (see: option {packet,line}),
% to the process with PID DispatcherPid.
handle(Socket,DispatcherPid) ->
	inet:setopts(Socket, [binary,{packet,line},{active, once}]),
		receive
			{tcp, Socket, Msg} ->
				DispatcherPid ! {event,utils:parse_input(Msg)},
				handle(Socket,DispatcherPid)
		end.
	