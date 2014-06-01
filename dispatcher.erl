-module(dispatcher).
-include("eventMessage.hrl").
-compile(export_all).

-record(state, {clients,
				currentMsgCount=0}).
				
% -record(clientRecord, {socket,
					   % workerPid}).
				
init() ->
	loop(#state{clients=dict:new()}).
			
loop(S = #state{}) ->
	receive
		{subscribe,ClientId,Socket} ->
			WorkerPid = spawn_link(fun() -> worker:init(Socket) end),
			gen_tcp:controlling_process(Socket,WorkerPid),
			NewClients = dict:append(ClientId,{[],Socket,WorkerPid},S#state.clients),
			loop(S#state{clients=NewClients});
		{event, Msg} ->
			OldMsgCount = S#state.currentMsgCount, 
			NewState = S#state{currentMsgCount=OldMsgCount+1}, 
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
		_ -> loop(S)
	after 5000 ->
		notifyFlushToWorkers(S)
	end.
	
notifyFlushToWorkers(S) -> 
	Pids = getWorkersPid(S),
	lists:foreach(fun(W) ->  W ! {forced_flush} end,Pids).
	
handleFollow(M = #eventMessage{},S = #state{}) -> 
	% Send message to worker who is in charge of delivering
	% messages to ``toUserId``
	case dict:find(M#eventMessage.toUser,S#state.clients) of
		{ok,[{_,_,ToUserWorkerPid}]} -> 
			ToUserWorkerPid ! {follow,S#state.currentMsgCount,M},
			SS = S#state{clients=dict:update(M#eventMessage.toUser,fun([{L,So,Wp}]) -> 
														[{[M#eventMessage.fromUser|L],So,Wp}] end,S#state.clients)},
			SS;
		error -> S
	end.

handleUnfollow(M = #eventMessage{},S = #state{}) -> 
	% We will not notify the client but we will 
	% tell him to drop ``fromUserId`` of his followers list
	case dict:find(M#eventMessage.fromUser,S#state.clients) of
		{ok,[{_,_,WorkerPid}]} -> 
			WorkerPid ! {unfollow,M#eventMessage.toUser},
			SS = S#state{clients=dict:update(M#eventMessage.fromUser,fun([{L,So,Wp}]) ->
													[{lists:delete(M#eventMessage.fromUser,L),So,Wp}] end,S#state.clients)},
			SS;
		error -> S
	end.

handleBroadcast(Msg,S = #state{}) ->
	% S#state.broadcasterPid ! {broadcast,S#state.currentMsgCount,Msg,getWorkersPid(S)}.
	lists:foreach(fun(A) -> A ! {broadcast,S#state.currentMsgCount, Msg} end,getWorkersPid(S)),
	S.
	
getWorkersPid(S = #state{}) ->
	dict:fold(fun(_,[{_,_,WorkerPid}],Acc) -> [WorkerPid|Acc] end,[],S#state.clients).
	
handlePrivateMessage(M = #eventMessage{},S = #state{}) -> 
	case dict:find(M#eventMessage.toUser,S#state.clients) of
		{ok,[{_,_,WorkerPid}]} -> 
			WorkerPid ! {private_message,S#state.currentMsgCount, M},
			S;
		error -> S
	end.

handleStatusUpdate(M = #eventMessage{},S = #state{}) ->
	case dict:find(M#eventMessage.fromUser,S#state.clients) of
		{ok,[{Followers,_,_}]} -> 
			FollowersPids = getFollowersPids(Followers,S),
			lists:foreach(fun(W) -> W ! {status_update,S#state.currentMsgCount,M} end, FollowersPids),
			S;
		error -> S
	end.
	
getFollowersPids([],_) -> [];
getFollowersPids(Followers,S = #state{}) ->
	lists:foldl(fun(E,Acc) ->  
							case dict:find(E,S#state.clients) of 
								{ok,[{_,_,WorkerPid}]} -> [WorkerPid|Acc];
								_ -> Acc
							end
							end,[],Followers).
	

% make_client_record(WorkerPid,Socket) ->
	% NewRecord = #clientRecord{socket=Socket,workerPid=WorkerPid},
	% % io:format("Made this record: ~p~n",[NewRecord]),
	% NewRecord.
			
			
		
	