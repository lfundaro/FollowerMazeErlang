-module(generic_server).
-export([start_server/3,acceptor/3]).


% This is a generic server. It consists of a function 
% start_server that spawns a new process a returns inmediatly. 
% The spawned process listens on Port, takes a DispatcherPid which is 
% responsible for handling any kind of request and finally it takes 
% a Handler function, that dictates how is the socket going to be treated 
% once a client request has been accepted.
start_server(Port, DispatcherPid, Handle) ->
	Pid = spawn(fun() ->
		{ok, Listen} = gen_tcp:listen(Port, [binary,{packet,line}, {active, false}]),
		spawn(fun() -> acceptor(Listen,DispatcherPid, Handle) end),
		receive
			{'EXIT', _, shutdown} ->
				gen_tcp:close(Listen),
				exit(normal)
		end
		end),
	{ok, Pid}.
	
% This process blocks on gen_tcp:accept waiting for new clients 
% to connect on ListenSocket. After accepting a connection, it calls 
% the handle function to treat such a request.
acceptor(ListenSocket,DispatcherPid, Handle) ->
	try gen_tcp:accept(ListenSocket) of 
		{ok, Socket} -> 
			spawn(fun() -> acceptor(ListenSocket,DispatcherPid,Handle) end),
			Handle(Socket,DispatcherPid);
		{error,closed} ->
			exit(normal)
	catch 
		_:_ -> exit(normal)
	end.