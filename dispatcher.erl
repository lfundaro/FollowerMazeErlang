-module(dispatcher).
-include("eventMessage.hrl").
-compile(export_all).

-record(state, {clients,
				currentMsgCount=0,
				counter_worker,
				followers}).
				
% -record(clientRecord, {socket,
					   % workerPid}).
				
init() ->
	loop(#state{clients = dict:new(),
				counter_worker = spawn_link(fun() -> counter_worker:init() end),
				followers=dict:new()}).
			
loop(S = #state{}) ->
	receive
		{subscribe,ClientId,Socket} ->
			WorkerPid = spawn_link(fun() -> worker:init(Socket) end),
			gen_tcp:controlling_process(Socket,WorkerPid),
			NewClients = dict:append(ClientId,WorkerPid,S#state.clients),
			loop(S#state{clients=NewClients});
		{event, Msg = #eventMessage{}} ->
			io:format("Got Event ~p~n",[Msg]),
			OldMsgCount = S#state.currentMsgCount, 
			NewState = S#state{currentMsgCount=OldMsgCount+1}, 
			%% Send information to CounterWorker
			% io:format("Send message to: ~p~n",[NewState#state.counter_worker]),
			NewState#state.counter_worker ! {new_event,Msg#eventMessage.seq,self()},
			case utils:typeOfMsg(Msg) of
				follow ->
					loop(handleFollow(Msg,NewState));
				unfollow ->
					loop(handleUnfollow(Msg,NewState));
				broadcast ->
					loop(handleBroadcast(Msg,NewState));
				private_message ->
					loop(handlePrivateMessage(Msg,NewState));
				status_update ->
					loop(handleStatusUpdate(Msg,NewState))
			end;
		{call_flush,From,To} ->
			% spawn(flush_broadcaster,deliver_flush_signal,[[From,To,getWorkersPid(S)]]),
			lists:foreach(fun(Wp) -> Wp ! {try_delivery,From,To} end,getWorkersPid(S)),
			loop(S);
		_ -> loop(S)
	% after 3000 ->
		% notifyFlushToWorkers(S)
	end.
	
% notifyFlushToWorkers(S) -> 
	% Pids = getWorkersPid(S),
	% lists:foreach(fun(W) ->  W ! {forced_flush} end,Pids).
	
handleFollow(M = #eventMessage{},S = #state{}) -> 
	% Primero vamos a agregar en la lista del usuario ToUser el follower
	SS = addFollower(M#eventMessage.fromUser,M#eventMessage.toUser,S),
	case dict:find(M#eventMessage.toUser,SS#state.clients) of
		{ok,[ToUserWorkerPid]} -> 
					ToUserWorkerPid ! {follow,SS#state.currentMsgCount,M},
					SS;
		_ -> SS
	end.
	
	% 634|S|32
	% 689|F|43|32
		% Send message to worker who is in charge of delivering
	% messages to ``toUserId``
	% case dict:find(M#eventMessage.toUser,S#state.clients) of
		% {ok,[{_,ToUserWorkerPid}]} -> 
			% ToUserWorkerPid ! {follow,S#state.currentMsgCount,M},
			% case dict:is_key(M#eventMessage.fromUser,S#state.clients) of 
				% true -> 
					% SS = S#state{clients=dict:update(M#eventMessage.toUser,fun([{L,So,Wp}]) -> 
													% [{[M#eventMessage.fromUser|L],So,Wp}] end,S#state.clients)},
					% SS;
				% false -> S 
			% end;
		% error -> S
	% end.
	
addFollower(NewFollower,To, S = #state{}) -> 
	S#state{followers=dict:update(To,fun(V) -> [NewFollower|V] end,[NewFollower], S#state.followers)}.
																
removeFollower(NewUnFollower,To, S = #state{}) -> 
	S#state{followers=dict:update(To,fun(V) -> lists:delete(NewUnFollower,V) end,[],S#state.followers)}.

handleUnfollow(M = #eventMessage{},S = #state{}) -> 
	% We will not notify the client but we will 
	% tell him to drop ``fromUserId`` of his followers list
	% case dict:find(M#eventMessage.fromUser,S#state.clients) of
		% {ok,[{_,_,WorkerPid}]} -> 
			% WorkerPid ! {unfollow,M#eventMessage.toUser},
			% SS = S#state{clients=dict:update(M#eventMessage.fromUser,fun([{L,So,Wp}]) ->
													% [{lists:delete(M#eventMessage.fromUser,L),So,Wp}] end,S#state.clients)},
			% SS;
		% error -> S
	% end.
	removeFollower(M#eventMessage.fromUser,M#eventMessage.toUser,S).
	% case dict:find(M#eventMessage.toUser,S#state.clients) of 
		% {ok,_} ->
			% SS = S#state{clients=dict:update(M#eventMessage.toUser,fun([{L,So,Wp}]) ->
											% [{lists:delete(M#eventMessage.fromUser,L),So,Wp}] end,S#state.clients)},
			% SS;
		% error -> S
	% end.
			

handleBroadcast(Msg,S = #state{}) ->
	% S#state.broadcasterPid ! {broadcast,S#state.currentMsgCount,Msg,getWorkersPid(S)}.
	lists:foreach(fun(A) -> A ! {broadcast,S#state.currentMsgCount, Msg} end,getWorkersPid(S)),
	S.
	
getWorkersPid(S = #state{}) ->
	dict:fold(fun(_,[WorkerPid],Acc) -> [WorkerPid|Acc] end,[],S#state.clients).
	
handlePrivateMessage(M = #eventMessage{},S = #state{}) -> 
	case dict:find(M#eventMessage.toUser,S#state.clients) of
		{ok,[WorkerPid]} -> 
			WorkerPid ! {private_message,S#state.currentMsgCount, M},
			S;
		error -> S
	end.

handleStatusUpdate(M = #eventMessage{},S = #state{}) ->
	%% Quitar esta restriccion !! 
	%% Es posible tener a un cliente que mande un status update
	%% dicho cliente no estar conectado pero sus followers SI, por 
	%% lo tanto no debemos revisar si es parte del pool de workers !!.
	% case dict:find(M#eventMessage.fromUser,S#state.clients) of
		% {ok,[{Followers,_,_}]} -> 
			% FollowersPids = getFollowersPids(Followers,S),
			% lists:foreach(fun(W) -> W ! {status_update,S#state.currentMsgCount,M} end, FollowersPids),
			% S;
		% error -> S
	% end.
	ListOfFollowers = retrieveFollowerList(M#eventMessage.fromUser,S),
	FollowersPids = lists:foldl(fun(E, Acc) -> 
											case dict:find(E, S#state.clients) of
												{ok,[WorkerPid]} -> [WorkerPid|Acc];
												error -> Acc
											end
											end, [], ListOfFollowers),
	lists:foreach(fun(W) -> W ! {status_update,S#state.currentMsgCount,M} end, FollowersPids),
	S.
	
retrieveFollowerList(User,S = #state{}) -> 
	case dict:find(User,S#state.followers) of 
		{ok,L} -> L;
		error -> []
	end.
	
getFollowersPids([],_) -> [];
getFollowersPids(Followers,S = #state{}) ->
	lists:foldl(fun(E,Acc) ->  
							case dict:find(E,S#state.clients) of 
								{ok,[WorkerPid]} -> [WorkerPid|Acc];
								_ -> Acc
							end
							end,[],Followers).
	

% make_client_record(WorkerPid,Socket) ->
	% NewRecord = #clientRecord{socket=Socket,workerPid=WorkerPid},
	% % io:format("Made this record: ~p~n",[NewRecord]),
	% NewRecord.
			
			
		
	