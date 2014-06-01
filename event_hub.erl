-module(event_hub).
-compile(export_all).
 
 init(DispatcherPid) -> 
	start_server(9090,DispatcherPid).
 
start_server(Port, DispatcherPid) ->
	Pid = spawn_link(fun() ->
		{ok, Listen} = gen_tcp:listen(Port, [binary,{packet,line}, {active, false}]),
		spawn(fun() -> acceptor(Listen,DispatcherPid) end),
		timer:sleep(infinity)
		end),
	{ok, Pid}.
 
acceptor(ListenSocket,DispatcherPid) ->
	{ok, Socket} = gen_tcp:accept(ListenSocket),
	spawn(fun() -> acceptor(ListenSocket,DispatcherPid) end),
	handle(Socket,DispatcherPid).
 
handle(Socket,DispatcherPid) ->
	inet:setopts(Socket, [binary,{packet,line},{active, once}]),
		receive
			{tcp, Socket, Msg} ->
				DispatcherPid ! {event,utils:parse_input(Msg)},
				handle(Socket,DispatcherPid)
		end.
	