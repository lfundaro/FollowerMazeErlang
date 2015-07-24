-module(worker).
-include("eventMessage.hrl").
-export([init/1,loop/1]).

-record(state, {clientSocket}).

init(Socket) ->
	process_flag(trap_exit, true),
	loop(#state{clientSocket=Socket}).
	
% This function listens to any message coming from the Dispatcher.
% Once this message is processed it is sent to the client that this 
% worker is responsible for. It also catches any shudown signal to
% close the socket before exiting.
loop(S = #state{}) -> 
	receive
		{notify,M} ->
			gen_tcp:send(S#state.clientSocket,M#eventMessage.payload),
			loop(S);
		{'EXIT', _, shutdown} ->
			gen_tcp:close(S#state.clientSocket),
			exit(normal);
		_ -> loop(S)   %ignore any other message.
	end.