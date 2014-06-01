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
			NewClients = dict:append(ClientId,{Socket,WorkerPid},S#state.clients),
			loop(S#state{clients=NewClients});
		{event, Msg} ->
			OldMsgCount = S#state.currentMsgCount, 
			NewState = S#state{currentMsgCount=OldMsgCount+1}, 
			case utils:typeOfMsg(Msg) of
				follow ->
					handleFollow(Msg,NewState);
				unfollow ->
					handleUnfollow(Msg,NewState);
				broadcast ->
					handleBroadcast(Msg,NewState);
				private_message ->
					handlePrivateMessage(Msg,NewState);
				status_update ->
					handleStatusUpdate(Msg,NewState)
			end,
			loop(NewState);
		_ -> loop(S)
	end.
	
handleFollow(M = #eventMessage{},S = #state{}) -> 
	% Send message to worker who is in charge of delivering
	% messages to ``toUserId``
	case dict:find(M#eventMessage.toUser,S#state.clients) of
		{ok,[{_,ToUserWorkerPid}]} -> 
			case dict:find(M#eventMessage.fromUser,S#state.clients) of
				{ok,[{_,FromUserWorkerPid}]} -> 
					ToUserWorkerPid ! {follow,S#state.currentMsgCount,M,FromUserWorkerPid};
				_ -> 
					ToUserWorkerPid ! {follow,S#state.currentMsgCount,M}
			end;
		error -> ignored
	end.

handleUnfollow(M = #eventMessage{},S = #state{}) -> 
	% We will not notify the client but we will 
	% tell him to drop ``fromUserId`` of his followers list
	case dict:find(M#eventMessage.fromUser,S#state.clients) of
		{ok,[{_,WorkerPid}]} -> 
			WorkerPid ! {unfollow,M#eventMessage.toUser};
		error -> ignored
	end.

handleBroadcast(Msg,S = #state{}) ->
	% S#state.broadcasterPid ! {broadcast,S#state.currentMsgCount,Msg,getWorkersPid(S)}.
	lists:foreach(fun(A) -> A ! {broadcast,S#state.currentMsgCount, Msg} end,getWorkersPid(S)).
	
getWorkersPid(S = #state{}) ->
	dict:fold(fun(_,[{_,WorkerPid}],Acc) -> [WorkerPid|Acc] end,[],S#state.clients).
	
handlePrivateMessage(M = #eventMessage{},S = #state{}) -> 
	case dict:find(M#eventMessage.toUser,S#state.clients) of
		{ok,[{_,WorkerPid}]} -> 
			WorkerPid ! {private_message,S#state.currentMsgCount, M};
		error -> ignored
	end.

handleStatusUpdate(M = #eventMessage{},S = #state{}) ->
	case dict:find(M#eventMessage.fromUser,S#state.clients) of
		{ok,[{_,WorkerPid}]} -> 
			WorkerPid ! {status_update,S#state.currentMsgCount,M};
		error -> ignored
	end.

% make_client_record(WorkerPid,Socket) ->
	% NewRecord = #clientRecord{socket=Socket,workerPid=WorkerPid},
	% % io:format("Made this record: ~p~n",[NewRecord]),
	% NewRecord.
			
			
		
	