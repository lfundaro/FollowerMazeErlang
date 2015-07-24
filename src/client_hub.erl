-module(client_hub).
-export([init/1]).

-define(PORT,9099).
 
 init(DispatcherPid) -> 
	generic_server:start_server(?PORT,DispatcherPid,fun handle/2).

% This is an implementation of the handle function that generic_server.erl 
% needs in order to process a new connection. In the case of this module, 
% the handle passes the ownership of Socket to the process with PID DispatcherPid 
% and it finally returns.
handle(Socket,DispatcherPid) ->
	inet:setopts(Socket, [binary,{packet,line},{active, once}]),
		receive
			{tcp, Socket, Msg} ->
				case gen_tcp:controlling_process(Socket, DispatcherPid) of 
					ok -> 
						DispatcherPid ! {subscribe,utils:parse_input(Msg),Socket};
					{error,_} -> error
				end,
				exit(normal)
		end.
	